// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

// OpenZeppelin Contracts (last updated v4.9.0) (access/Ownable.sol)

// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby disabling any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

contract DecentNews is Ownable {
    mapping(address => bool) public isApproved; //User allowed to publish article
    mapping(address => bytes32[]) articlesReviewed;
    mapping(address => bytes32[]) articlesCreated;

    //Creation
    mapping(bytes32 => address) articleCreator; //Creator of Article
    mapping(bytes32 => uint) indexOfArticlePending;
    mapping(bytes32 => ArticleState) stateOfArticle;

    //Review
    mapping(address => bytes32) assignedArticleReviewer;
    mapping(bytes32 => pendingArticle) public articleReviewState; //every positive review count increases by 1

    //Payment
    mapping(address => int256) public userFunds;
    bytes32[] public pendingArticles;

    //MVP Earnings set
    int256 earningsPerApprovedArticle = 0.01 ether;
    int256 earningsPerCorrectReview = -0.001 ether;
    int256 reductionPerDeclinedArticle = 0.01 ether;
    int256 earningsFalseReview = -0.001 ether;

    uint256 reviewsNeeded = 3; //3 for testing 10 reviews needed
    uint256 minimumScoreToApprove = 1; //minimum five votes in order for article to be improved
    uint256 amountNeededToParticipate = 0.001 ether;
    uint256 randNonce;

    struct pendingArticle {
        uint256 voteCount;
        uint256 score;
        address[] reviewee;
        mapping(address => bool) voteOfParticipant;
        bool result;
        bool finished;
    }

    enum ArticleState {
        Pending,
        Approved,
        Rejected
    }

    //Approved articles saved in Events
    event articleApproved(bytes32 hash);
    event articleCreated(bytes32 hash);
    event reviewAssigned(address indexed reviewee, bytes32 hash);
    event rewardsCalculated(address indexed reviewee, int256 amount);
    event Withdrawal(address indexed reviewee, uint256 amount);
   
    //MVP everything already set
    constructor() payable {

    }

    function createArticle(bytes32 _hash) external {
       //require(isApproved[msg.sender], "User not allowed to create articles");
       
        articleCreator[_hash] = msg.sender;
        stateOfArticle[_hash] = ArticleState.Pending;

        indexOfArticlePending[_hash] = pendingArticles.length;
        pendingArticles.push(_hash);
        emit articleCreated(_hash);
    }

    function requestReview() external {
       // require(isApproved[msg.sender], "User not allowed to review articles");
        require(assignedArticleReviewer[msg.sender] == bytes32(0), "User already has review assigned");
        require(pendingArticles.length > 0, "No article available for review");
        //requestRandomNumber
        uint256 maxNumber = pendingArticles.length; //0 - maxNumber = randomNumber
        uint256 indexOfRandomArticle = randomNumber(maxNumber);
        if(indexOfRandomArticle > 0) indexOfRandomArticle --;
        assignedArticleReviewer[msg.sender] = pendingArticles[indexOfRandomArticle];

        emit reviewAssigned(msg.sender, pendingArticles[indexOfRandomArticle]);
    }

    //assign 
    function submitVote(bool validArticle) external {
        require(assignedArticleReviewer[msg.sender] != bytes32(0), "No article assigned");
        //If article has max amount of reviews abord
        bytes32 assignedArticle = assignedArticleReviewer[msg.sender];
        if(articleReviewState[assignedArticle].finished){
            assignedArticleReviewer[msg.sender] = bytes32(0);
        }

        if(validArticle){
            articleReviewState[assignedArticle].score++;
        }
        articleReviewState[assignedArticle].voteCount++;

        if( articleReviewState[assignedArticle].voteCount >= reviewsNeeded){
            finalizeVoting(assignedArticle);
        }
        articleReviewState[assignedArticle].reviewee.push(msg.sender);
        assignedArticleReviewer[msg.sender] = bytes32(0);
    }

    function finalizeVoting(bytes32 _hash) internal {
        articleReviewState[_hash].finished = true;
        // Delete from pending Reviews
        uint256 indexHash = indexOfArticlePending[_hash];
        if(pendingArticles.length > 1){
            pendingArticles[indexHash] = pendingArticles[pendingArticles.length - 1];
        }
        pendingArticles.pop();
        
        if(articleReviewState[_hash].score > minimumScoreToApprove){
            emit articleApproved(_hash);
            stateOfArticle[_hash] = ArticleState.Approved;
            articleReviewState[_hash].result = true;
        }else{
            stateOfArticle[_hash] = ArticleState.Approved;
            articleReviewState[_hash].result = false;
        }
    }

    function calculateReward() public {
        // Initialize rewards as 0
        int256 rewards = 0;

        // Iterate through the articles reviewed by the sender
        uint256 i = 0;
        while (i < articlesReviewed[msg.sender].length) {
            bytes32 articleHash = articlesReviewed[msg.sender][i];
            pendingArticle storage article = articleReviewState[articleHash];
            if (article.finished) {
                if (article.voteOfParticipant[msg.sender] == article.result) {
                    rewards += earningsPerCorrectReview;
                } else {
                    rewards -= earningsFalseReview;
                }
                articlesReviewed[msg.sender][i] = articlesReviewed[msg.sender][articlesReviewed[msg.sender].length - 1];
                articlesReviewed[msg.sender].pop();
            } else {
                ++i;
            }
        }

        // Iterate through the articles created by the sender
        uint256 y = 0;
        while (y < articlesCreated[msg.sender].length) {
            bytes32 articleHash = articlesCreated[msg.sender][y];
            pendingArticle storage article = articleReviewState[articleHash];
            if (article.finished) {
                if (article.result) {
                    rewards += earningsPerApprovedArticle;
                } else {
                    rewards -= reductionPerDeclinedArticle;
                }
                articlesCreated[msg.sender][y] = articlesCreated[msg.sender][articlesCreated[msg.sender].length - 1];
                articlesCreated[msg.sender].pop();
            } else {
                ++y;
            }
        }
        userFunds[msg.sender] += rewards;
        // Emit an event with the calculated rewards (assuming you have this event defined)
        emit rewardsCalculated(msg.sender, rewards);
    }

function withdraw(uint256 _amount) external {
    calculateReward();
    int256 totalFunds = userFunds[msg.sender];
    require(totalFunds >= 0, "No funds available to withdraw");
    require(_amount > 0 && uint256(totalFunds) >= _amount, "Invalid withdrawal amount");

    uint256 remainingAmount = uint256(totalFunds) - _amount;
    if (remainingAmount < amountNeededToParticipate) {
        require(checkIfWithdrawAllowed(), "Pending reviews, withdraw not possible");
        isApproved[msg.sender] = false;
    }

    // Update the user's funds
    userFunds[msg.sender] = int256(remainingAmount);

    // Transfer the requested amount to the user
    payable(msg.sender).transfer(_amount);

    // Optionally, you can emit an event to log the withdrawal
    emit Withdrawal(msg.sender, _amount);
}

    function stake() external payable{
        require(msg.value > amountNeededToParticipate, "Not enough funds");
        //@todo Overflow??
        userFunds[msg.sender] += int256(msg.value);
        isApproved[msg.sender] = true;
    }
    
    function getAssignedArticle(address _user) public view returns (bytes32){
        return assignedArticleReviewer[_user];
    }
    function checkIfWithdrawAllowed() internal view returns (bool) {
        if(articlesReviewed[msg.sender].length == 0 && articlesCreated[msg.sender].length == 0){
            return true;
        }
        return false;

    }

    //Will be replaced with Chainlink
     function randomNumber(uint _modulus) internal virtual returns (uint) {
        randNonce++;
        return
            uint(
                keccak256(
                    abi.encodePacked(
                        block.timestamp,
                        msg.sender,
                        randNonce,
                        _modulus
                    )
                )
            ) % _modulus;
    }
}
