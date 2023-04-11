// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol"; 
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./MultSigWallet.sol";

contract DeMarketplace is ERC721URIStorage {

    using Counters for Counters.Counter; 

    event MarketItemListed(
        uint256 indexed tokenId,
        address owner,
        uint256 price,
        address  seller,
        bool sold,
        bool islisted
    );  

    event MarketItemMinted(
        uint256 indexed tokenId,
        address owner,
        uint256 price,
        address  seller,
        bool sold,
        bool islisted
    );  
                                            
    event MarketItemBought(
        uint256 indexed tokenId,
        address owner,
        uint256 indexed price,
        address  seller,
        bool sold,
        bool islisted
    );  

    event MarketItemRelisted(
        uint256 indexed tokenId,
        address owner,
        uint256 price,
        address  seller,
        bool sold,
        bool islisted
    ); 


    IERC20 MPT;
    MultiSigWallet MultSigWalletContract;

    Counters.Counter private _tokenIds;   //track of tokens
    Counters.Counter private _tokensSold; //track of token sold
    uint256 listingPrice = 0.0007 ether; //listing price charged at every listing
    address owner;
    uint maxTokensPerWallet = 5;

    struct S_MarketItem {
        uint256 tokenId;
        address owner;
        uint256 price;
        address seller;
        bool sold;
        bool islisted;
    }
    mapping(uint256 => S_MarketItem) public m_marketItems; //id to market item struct- record of market items and their details
    mapping(address => uint256) m_tokensPerUser;


    constructor(IERC20 _MPTContractAddress, MultiSigWallet _wallet ) ERC721("DeMarkt", "DMT") {
        owner = msg.sender;
        MPT = _MPTContractAddress;
        MultSigWalletContract = _wallet;
    }

    modifier isOwner() {
        require(msg.sender == owner, "only the owner can modify this");
        _;
    }

    function updateListingPrice(uint256 _listingPrice) public isOwner {   //in prog
        listingPrice = _listingPrice;
    }

    function getListingPrice() public view returns (uint256) {
        return listingPrice;
    }

    function getLatestToken() public view returns (S_MarketItem memory) {
        return m_marketItems[_tokenIds.current()];
    }

    function mintToken(string memory _tokenURI) public returns (uint256) {
        require(m_tokensPerUser[msg.sender] <= maxTokensPerWallet, "max 5 tokens allowed!");
        
        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current(); 
        

        m_marketItems[newTokenId] = S_MarketItem(
            newTokenId,
            (address(this)), //owner
            0,         //price will be 0 bec not yet listed
            (msg.sender),    //seller
            false,                  //not sold 
            false                   //not up for sale 
        );
        ++m_tokensPerUser[msg.sender];
        _mint(msg.sender, newTokenId);
        _setTokenURI(newTokenId, _tokenURI);
        _transfer(msg.sender, address(this), newTokenId); //we send the asset to the contract when we mint it.

        emit MarketItemMinted(
            newTokenId,
            (address(this)), //owner
            0,         //price will be 0 bec not yet listed
            (msg.sender),    //seller
            false,                  //not sold 
            false                   //not up for sale
        );

        return newTokenId;
    }

    function listTokenForSale (uint256 _tokenId, uint256 _tokenPrice) public returns(uint256){
        
        require(m_marketItems[_tokenId].tokenId != 0,"token does not exist" );
        require(msg.sender == m_marketItems[_tokenId].seller, "you are not allowed to list this item" );
        require(m_marketItems[_tokenId].islisted == false, "This item is already listed");
        require(_tokenPrice >= listingPrice, "price shoud be greater than listing price i.e > 0.0007 ether");

        
        m_marketItems[_tokenId].price   = _tokenPrice;             
        m_marketItems[_tokenId].islisted= true;                   
        
        
        emit MarketItemListed(
            _tokenId,
            m_marketItems[_tokenId].owner,
            _tokenPrice,
            (msg.sender),
            false,
            true
        );
        
        return _tokenId;
    }


    function buyMarketItem(uint256 _tokenId) public  {
        
        address seller = m_marketItems[_tokenId].seller;
        require(m_marketItems[_tokenId].tokenId != 0,"token does not exist" );
        require(m_marketItems[_tokenId].islisted == true, "Token is not listed for sale");
        require(msg.sender != seller, "seller cannot buy their own token");
        
        
        m_marketItems[_tokenId].sold        = true;
        m_marketItems[_tokenId].islisted    = false;
        m_marketItems[_tokenId].owner       = msg.sender; //function caller who buys the item is now the owner
        m_marketItems[_tokenId].seller      = msg.sender; //seller does not exist now

        _tokensSold.increment();
        _transfer(address(this), msg.sender, _tokenId); //

        // (owner).transfer(listingPrice); //comission charged by the main owner of marketplace
        // (seller).transfer(m_marketItems[_tokenId].price);   //transfer the token's price to the token's seller
        require(IERC20(MPT).transferFrom(msg.sender, address(MultSigWalletContract) , listingPrice), "token transfer to address failed");
        require(IERC20(MPT).transferFrom(msg.sender, seller ,m_marketItems[_tokenId].price ), "token transfer to seller failed");
        
        emit MarketItemBought(
            
            _tokenId,
            msg.sender ,
            m_marketItems[_tokenId].price,
            msg.sender,
            false,
            true
        
        );
    }

    function relistTokenForSale(uint256 _tokenId, uint256 _tokenPrice) public {
        
        require(m_marketItems[_tokenId].tokenId != 0,"token does not exist" );
        require(msg.sender == m_marketItems[_tokenId].owner && msg.sender == m_marketItems[_tokenId].seller , "you should be the owner to resell this item");
        require(_tokenPrice >= listingPrice, "price shoud be greater than listing price i.e > 0.0007 ether");

        m_marketItems[_tokenId].sold        = false;
        m_marketItems[_tokenId].islisted    = true;
        m_marketItems[_tokenId].owner       = (address(this));
        m_marketItems[_tokenId].price       = _tokenPrice;

        _tokensSold.decrement();
        _transfer(msg.sender, address(this), _tokenId);

        emit MarketItemListed(
            _tokenId,
            (address(this)),
            _tokenPrice,
            (msg.sender),
            false,
            true
        );
        
    }

    function getContractBalance() public view returns(uint){
        return IERC20(MPT).balanceOf(address(this));
    }

    function getUnsoldItems() public view returns (S_MarketItem[] memory) {
        uint256 totalNFTs = _tokenIds.current(); //total tokens created so far
        uint256 totalUnsoldNFTs = _tokenIds.current() - _tokensSold.current(); //total unsold
        uint256 curPtr = 0;

        S_MarketItem[] memory unsoldItems = new S_MarketItem[](totalUnsoldNFTs); // array with size of unsold nfts

        for (uint256 i = 0; i < totalNFTs; i++) {
            // run loop till < unsolditems
            if (m_marketItems[i + 1].owner == address(this)) {
                // if struct has owner == contract, then
                uint256 currentId = i + 1; //
                S_MarketItem storage currentItem = m_marketItems[currentId];
                unsoldItems[curPtr] = currentItem;
                curPtr += 1;
            }
        }
        return unsoldItems;
    }

    function getOwnedItems() public view returns (S_MarketItem[] memory) {
        uint256 totalCount = _tokenIds.current();
        uint256 itemCount = 0;
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < totalCount; i++) {
            if (m_marketItems[i + 1].owner == msg.sender) {
                itemCount += 1;
            }
        }

        S_MarketItem[] memory Items = new S_MarketItem[](itemCount);
        for (uint256 i = 0; i < totalCount; i++) {
            if (m_marketItems[i + 1].owner == msg.sender) {
                uint256 currentId = i + 1;
                S_MarketItem storage currentItem = m_marketItems[currentId];
                Items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return Items;
    }

    function getSellerItems() public view returns (S_MarketItem[] memory) {        
        uint256 totalCount = _tokenIds.current();
        uint256 itemCount = 0;
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < totalCount; i++) {
            if (m_marketItems[i + 1].seller == msg.sender ){
                itemCount += 1;
            }
        }

        S_MarketItem[] memory Items = new S_MarketItem[](itemCount);
        for (uint256 i = 0; i < totalCount; i++) {
            if (m_marketItems[i + 1].seller == msg.sender) {
                uint256 currentId = i + 1;
                S_MarketItem storage currentItem = m_marketItems[currentId];
                Items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return Items;
    }
}





