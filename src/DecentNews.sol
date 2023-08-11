// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

contract DecentNews {
    mapping(bytes32 => address) articleCreator; //Creator of Article
    mapping(address => bool) isApproved; //User allowed to publish article
    mapping(bytes32 => uint) indexOfArticlePending;
    mapping(bytes32 => ArticleState) stateOfArticle;

    //Review
    mapping(address => bytes32) assignedArticleReviewer;
    mapping(bytes32 => pendingArticle) articleReviewState; //every positive review count increases by 1

    bytes32[] public pendingArticles;

    uint256 reviewsNeeded = 10; //10 reviews needed
    uint256 minimumScoreToApprove = 5; //minimum five votes in order for article to be improved
    uint256 randNonce;


    struct pendingArticle {
        uint256 voteCount;
        uint256 score;
        address[] reviewee;
        mapping(address => bool) voteOfParticipant;
        uint256 finalScore;
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
    function createArticle(bytes32 _hash) public {
        require(isApproved[msg.sender], "User not allowed to create Articles");
       
        articleCreator[_hash] = msg.sender;
        stateOfArticle[_hash] = ArticleState.Pending;

        indexOfArticlePending[_hash] = pendingArticles.length;
        pendingArticles.push(_hash);
        emit articleCreated(_hash);
    }

    function requestReview() public {
        require(isApproved[msg.sender], "User not allowed to review Articles");
        require(assignedArticleReviewer[msg.sender] == bytes32(0), "User already has review assigned");

        //requestRandomNumber
        uint256 maxNumber = pendingArticles.length - 1; //0 - maxNumber = randomNumber
        uint256 indexOfRandomArticle = randomNumber(maxNumber);
        assignedArticleReviewer[msg.sender] = pendingArticles[indexOfRandomArticle];

        emit reviewAssigned(msg.sender, pendingArticles[indexOfRandomArticle]);
    }

    //assign 
    function submitVote(bool validArticle) public {
        require(assignedArticleReviewer[msg.sender] != bytes32(0), "No article for review assigned");
        //If article has max amount of reviews abord
        bytes32 assignedArticle = assignedArticleReviewer[msg.sender];
        if(articleReviewState[assignedArticle].finished){
            assignedArticleReviewer[msg.sender] = bytes32(0);
        }

        if(validArticle){
            articleReviewState[assignedArticle].score++;
        }
        articleReviewState[assignedArticle].voteCount++;

        if( articleReviewState[assignedArticle].voteCount > reviewsNeeded){
            finalizeVoting(assignedArticle);
        }

        assignedArticleReviewer[msg.sender] = bytes32(0);
    }


    function finalizeVoting(bytes32 _hash) internal {
        
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
