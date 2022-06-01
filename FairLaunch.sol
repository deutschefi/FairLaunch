// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;

        return c;
    }

    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0);
        return a % b;
    }
}

interface IERC20 {
    function totalSupply() external view returns (uint256);

    function balanceOf(address who) external view returns (uint256);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function transfer(address to, uint256 value) external returns (bool);

    function approve(address spender, uint256 value) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}

interface IBEP20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the token decimals.
     */
    function decimals() external view returns (uint8);

    /**
     * @dev Returns the token symbol.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the token name.
     */
    function name() external view returns (string memory);

    function getOwner() external view returns (address);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address recipient, uint256 amount)
        external
        returns (bool);

    function allowance(address _owner, address spender)
        external
        view
        returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}

abstract contract ERC20Detailed is IERC20 {
    string private _name;
    string private _symbol;
    uint8 private _decimals;

    constructor(
        string memory _tokenName,
        string memory _tokenSymbol,
        uint8 _tokenDecimals
    ) {
        _name = _tokenName;
        _symbol = _tokenSymbol;
        _decimals = _tokenDecimals;
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view returns (uint8) {
        return _decimals;
    }
}

contract FairLaunch {
    using SafeMath for uint256;

    address token;
    address busdToken = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
    address owner = 0x6aAF9b7E170b7bAA6a75EB2C3D63d1cc397690e0;
    address payable public liquidityReceiver =
        payable(0x4Acc87922b9768De2e6388E2D06697F1AE362971);
    address payable public treasury =
        payable(0x3C42D87cF99EDfBBE1738Cc3c6996BE66ae32aCF);

    uint256 public bnbRate;
    uint256 public busdRate = 8;
    uint256 public decimals = 10**18;
    uint256 public minBuy = 10 * decimals;
    uint256 public maxBuy = 3000 * decimals;
    uint256 public goal = 300000 * decimals;
    uint256 public totalRaised;

    bool public hasEnded = false;

    mapping(address => bool) whitelist;
    mapping(address => uint256) public totalPurchased;

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    event TokenPurchase(
        address indexed purchaser,
        uint256 value,
        uint256 amount
    );

    constructor(uint256 _rate, address _token) {
        require(_rate > 0);
        bnbRate = _rate;
        token = _token;
    }

    receive() external payable {
        buyTokens();
    }

    function buyTokens() public payable {
        uint256 weiAmountInBusd = (msg.value).mul(bnbRate);
        uint256 tokens = _getTokenAmount(weiAmountInBusd);

        _prevalidate(weiAmountInBusd);
        _deliverTokens(tokens);
        _updatePurchasingState(weiAmountInBusd);
        _forwardFunds();

        emit TokenPurchase(msg.sender, weiAmountInBusd, tokens);
    }

    function buyTokensWithBUSD(uint256 busdAmount) public payable {
        uint256 tokens = _getTokenAmount(busdAmount);

        _prevalidate(busdAmount);
        _deliverTokens(tokens);
        _updatePurchasingState(busdAmount);
        _forwardBusd(busdAmount);

        emit TokenPurchase(msg.sender, busdAmount, tokens);
    }

    function _prevalidate(uint256 _weiAmount) internal view {
        require(!hasEnded, "Presale ended");
        require(totalRaised <= goal, "Reached presale limit");
        require(_weiAmount >= minBuy, "Buy amount too low");
        require(
            totalPurchased[msg.sender].add(_weiAmount) < maxBuy,
            "Buy limit reached. Try a lower amount."
        );
    }

    function _deliverTokens(uint256 _tokenAmount) internal {
        ERC20Detailed(token).transfer(msg.sender, _tokenAmount);
    }

    function _updatePurchasingState(uint256 _weiAmount) internal {
        totalRaised = totalRaised.add(_weiAmount);
        totalPurchased[msg.sender] = totalPurchased[msg.sender].add(_weiAmount);
    }

    function _getTokenAmount(uint256 _weiAmount)
        internal
        view
        returns (uint256)
    {
        uint256 baseAmount = _weiAmount.mul(100).div(busdRate);
        if (whitelist[msg.sender]) {
            return baseAmount.mul(2);
        } else {
            return baseAmount;
        }
    }

    function _forwardFunds() internal {
        (bool success, ) = liquidityReceiver.call{
            value: msg.value.mul(70).div(100),
            gas: 30000
        }("");
        (success, ) = treasury.call{
            value: msg.value.mul(30).div(100),
            gas: 30000
        }("");
    }

    function _forwardBusd(uint256 _busdAmount) internal {
        IBEP20(busdToken).transferFrom(
            msg.sender,
            liquidityReceiver,
            _busdAmount.mul(70).div(100)
        );
        IBEP20(busdToken).transferFrom(
            msg.sender,
            treasury,
            _busdAmount.mul(30).div(100)
        );
    }

    function sendTokens(uint256 _tokenAmount, address _token)
        external
        onlyOwner
    {
        ERC20Detailed(_token).transfer(msg.sender, _tokenAmount);
    }

    function updateBnbRate(uint256 _rate) external onlyOwner {
        bnbRate = _rate;
    }

    function updateWhitelist(address[] calldata recipients) external onlyOwner {
        for (uint256 i = 0; i < recipients.length; i++) {
            whitelist[recipients[i]] = true;
        }
    }

    function checkWhitelist(address _address) external view returns (bool) {
        return whitelist[_address];
    }

    function clearBalance() external onlyOwner {
        uint256 amount = address(this).balance;
        treasury.transfer(amount);
    }

    function endSale() external onlyOwner {
        hasEnded = true;
    }
}
