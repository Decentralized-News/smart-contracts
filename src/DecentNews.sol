// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";

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
    uint256 amountNeededToParticipate = 0.01 ether;
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
    event articleApproved(bytes32);
    event articleCreated(bytes32);
    event reviewAssigned(address indexed, bytes32);
    event rewardsCalculated(address indexed, int256);
    event Withdrawal(address indexed, uint256);
   
    //MVP everything already set
    constructor() payable {

    }

    function createArticle(bytes32 _hash) external {
        require(isApproved[msg.sender], "User not allowed to create articles");
       
        articleCreator[_hash] = msg.sender;
        stateOfArticle[_hash] = ArticleState.Pending;

        indexOfArticlePending[_hash] = pendingArticles.length;
        pendingArticles.push(_hash);
        emit articleCreated(_hash);
    }

    function requestReview() external {
        require(isApproved[msg.sender], "User not allowed to review articles");
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
