// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";


/**
 * @title DecentNews
 * @dev A contract for dezentralized publishing and reviewing articles.
 *      Utilizes Chainlink VRF for random selection in reviews.
 */
contract DecentNews is VRFConsumerBaseV2 {
     // Chainlink related Variables
    VRFCoordinatorV2Interface COORDINATOR;
    uint64 s_subscriptionId = 4463;
    uint256[] public requestIds;
    uint256 public lastRequestId;
    bytes32 keyHash =
        0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c;
    uint32 callbackGasLimit = 100000;
    uint16 requestConfirmations = 3;
    uint32 numWords = 1;

    struct RequestStatus {
        bool fulfilled; // whether the request has been successfully fulfilled
        bool exists; // whether a requestId exists
        uint256[] randomWords;
    }
    
    mapping(uint256 => RequestStatus) public s_requests;
    
    //Users
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

    //Earnings set (MVP)
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

    //Events
    event articleApproved(bytes32 hash);
    // event articleCreated(bytes32 hash);
    // event reviewAssigned(address indexed reviewee, bytes32 hash);
    // event rewardsCalculated(address indexed reviewee, int256 amount);
    // event Withdrawal(address indexed reviewee, uint256 amount);
   
    //MVP everything already set
    constructor() VRFConsumerBaseV2(0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625) payable {
         COORDINATOR = VRFCoordinatorV2Interface(
            0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625
        );
    }

     /**
     * @dev Function to create an article.
     * @param _hash The hash of the article.
     */
    function createArticle(bytes32 _hash) external {
       //require(isApproved[msg.sender], "User not allowed to create articles");
       
        articleCreator[_hash] = msg.sender;
        stateOfArticle[_hash] = ArticleState.Pending;

        indexOfArticlePending[_hash] = pendingArticles.length;
        pendingArticles.push(_hash);
        // emit articleCreated(_hash);
    }

    /**
     * @dev Function to request review of an article.
     */
    function requestReview() external {
       // require(isApproved[msg.sender], "User not allowed to review articles");
        require(assignedArticleReviewer[msg.sender] == bytes32(0), "User already has review assigned");
        require(pendingArticles.length > 0, "No article available for review");
        uint256 maxNumber = pendingArticles.length; //0 - maxNumber = randomNumber
       //chainlink requestRandomNumber
        uint256 indexOfRandomArticle = requestRandomWords(maxNumber);
        if(indexOfRandomArticle > 0) indexOfRandomArticle --;
        assignedArticleReviewer[msg.sender] = pendingArticles[indexOfRandomArticle];

        // emit reviewAssigned(msg.sender, pendingArticles[indexOfRandomArticle]);
    }

    /**
     * @dev Function to submit vote for review.
     * @param validArticle indicates if the article is valid.
     */
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



    /**
     * @dev Function to calculate rewards for a user.
     */
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
        // emit rewardsCalculated(msg.sender, rewards);
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

    // emit Withdrawal(msg.sender, _amount);
}


    function stake() external payable{
        require(msg.value > amountNeededToParticipate, "Not enough funds");
        //@todo overflow??
        userFunds[msg.sender] += int256(msg.value);
        isApproved[msg.sender] = true;
    }
    
    function getAssignedArticle(address _user) external view returns (bytes32){
        return assignedArticleReviewer[_user];
    }

    function getRequestStatus(
        uint256 _requestId
    ) external view returns (bool fulfilled, uint256[] memory randomWords) {
        require(s_requests[_requestId].exists, "request not found");
        RequestStatus memory request = s_requests[_requestId];
        return (request.fulfilled, request.randomWords);
    }

    /**
     * @dev Internal function to finalize voting.
     * @param _hash The hash of the article.
     */
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

    function checkIfWithdrawAllowed() internal view returns (bool) {
        if(articlesReviewed[msg.sender].length == 0 && articlesCreated[msg.sender].length == 0){
            return true;
        }
        return false;

    }
    

     /**
     * @dev Request random words from Chainlink VRF.
     * @return requestId The request ID of the random words request.
     */
    function requestRandomWords(uint _modulus)
        internal
        returns (uint256 requestId)
    {
        // Will revert if subscription is not set and funded.
        requestId = COORDINATOR.requestRandomWords(
            keyHash,
            s_subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            numWords
        );
        s_requests[requestId] = RequestStatus({
            randomWords: new uint256[](0),
            exists: true,
            fulfilled: false
        });
        requestIds.push(requestId);
        lastRequestId = requestId;
        return requestId % _modulus;
    }

    function fulfillRandomWords(
        uint256 _requestId,
        uint256[] memory _randomWords
    ) internal override {
        require(s_requests[_requestId].exists, "request not found");
        s_requests[_requestId].fulfilled = true;
        s_requests[_requestId].randomWords = _randomWords;
    }
}
