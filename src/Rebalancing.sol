// SPDX-License-Identifier: NONE
pragma solidity ^0.8.20;

/// @title An ERC20 who's totalSupply and user balances are always increasing
/// @notice The idea is that these tokens represent votes in a governance process
/// and holders' votes gain value over time.
contract Rebalancer {

    uint256 private constant ONE = 1e18;
    uint256 public constant decimals = 18;
    uint256 public immutable voteGrowthStartTime;
    uint256 public immutable voteGrowthPerSecond;
    uint256 public immutable totalVoteShares;

    mapping(address account => uint256 shares) public userVoteShares;
    mapping(address account => mapping(address spender => uint256)) public allowances;


    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);



    /// @notice Constructs the contract. It gives all tokens to the calling address for them 
    /// to distribute.
    /// @param _totalVoteShares the total number of initial tokens to mint, becomes the total
    /// number of total shares as they gain value
    /// @param _voteGrowthPerYear an 18 decimal percentage that represents the simple interest
    /// a vote accrues over a year. I.e. 6% growth should be 0.06 ether
    constructor(uint256 _totalVoteShares, uint256 _voteGrowthPerYear) {
        uint256 secondsPerYear = 60*60*24*365; // leap years be damned
        voteGrowthPerSecond = _voteGrowthPerYear / secondsPerYear;
        voteGrowthStartTime = block.timestamp;
        userVoteShares[msg.sender] = _totalVoteShares;
        emit Transfer(address(0x00), msg.sender, _totalVoteShares);
        totalVoteShares = _totalVoteShares;
    }

    /// @notice Calculate the total growth of shares over time
    /// @dev Since all tokens are minted at construction, we can skip having to
    /// checkpoint each users "interest index" whenever they receive shares.
    /// @return the vote "multiplier" that when multiplied by shares, gives
    /// the total number of votes it is worth
    function computeVoteGrowth() view internal returns(uint256) {
        uint256 timeElapsed = block.timestamp - voteGrowthStartTime;
        return ONE + (voteGrowthPerSecond * timeElapsed);
    }

    /// @notice Returns the number of votes a vote share is worth
    /// @param _shares the number of which we would like to convert to tokens (i.e. votes) 
    /// @return the number of tokens (i.e. votes) the shares are worth 
    function getPresentTokenCount(uint256 _shares) view internal returns(uint256){
        return _shares * computeVoteGrowth() / ONE;
    }

    /// @notice Returns the total supply of tokens at this very moment
    /// @return the total number of tokens in circulation
    function totalSupply() view public  returns (uint256){
        return getPresentTokenCount(totalVoteShares);
    }

    /// @notice Returns the current token count of an address
    /// @param _owner The address we would like to see the token count of
    /// @return The total number of tokens owned by the specified address
    function balanceOf(address _owner) public view returns (uint256){
        return getPresentTokenCount(userVoteShares[_owner]);
    }

    /// @notice Transfer an amount of tokens to another user
    /// @dev Because we store vote shares instead of votes, we need to convert the 
    ///      specified _value into a share amount before we can modify user balances
    /// @dev Emit `Transfer` event to register token transfer from sender (`msg.sender`)  
    /// @param _to The address to transfer vote tokens to
    /// @param _value The amount of vote tokens to transfer
    /// @return Whether the transfer succeeded or not
    function transfer(address _to, uint256 _value) public returns (bool){
        // we check if their shares are worth that much
        if(balanceOf(msg.sender) < _value){
          return false;
        }

        uint256 valueAsShares = (_value * ONE) / computeVoteGrowth();
        userVoteShares[_to] +=  valueAsShares;
        userVoteShares[msg.sender] -= valueAsShares;
        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    /// @notice Transfer tokens from one address to another if allowed
    /// @dev We always check for allowance. msg.sender should use transfer instead
    /// @param _from The address to transfer from
    /// @param _to The address to transfer to
    /// @param _value The amount of vote tokens to transfer
    /// @return Whether or not the transfer succeeded. Does not specify what went wrong if it did.
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool){
        // we always check for allowance, msg.sender should use transfer instead
        if(allowances[_from][_to] < _value ){
            return false;
        }
        if(balanceOf(_from) < _value){
            return false;
        }

        uint256 valueAsShares = (_value * ONE) / computeVoteGrowth();
        userVoteShares[_to] +=  valueAsShares;
        userVoteShares[_from] -= valueAsShares;
        allowances[_from][_to] -= _value;

        return true;
    }

    /// @notice Allow another user to transfer a specified amount of tokens away from the caller
    /// @dev We do not enforce any behavior here. For example, users do not have to set 
    ///      an allowance to zero first before being able to change a users allowance.
    /// @dev Emit `Approval` event to register approval of sender address (`msg.sender`)  
    /// @param _spender The address for which the caller will allow token access
    /// @param _value The amount of vote tokens the caller will allow the _spender to transfer
    /// @return Whether the approval succeeded
    function approve(address _spender, uint256 _value) public returns (bool){
        allowances[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);  
        return true;
    }

}