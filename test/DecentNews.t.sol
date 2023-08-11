// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import "../src/DecentNews.sol";

contract DecentNewsTestAfterSetUp is Test {
    event rewardsCalculated(address indexed, int256);

    DecentNews public decentNews;
    function setUp() public {
        decentNews = new DecentNews();

    }
    function test_publishArticle(bytes32 _hash) public {
        vm.expectRevert("User not allowed to create articles");
        decentNews.createArticle(_hash);
    }
    function test_reviewArticle() public {
        vm.expectRevert("User not allowed to review articles");
        decentNews.requestReview();
    }

    function test_submitVote(bool validArticle) public {
        vm.expectRevert("No article assigned");
        decentNews.submitVote(validArticle);
    }
    
    function test_calculateReward() public {
        //@todo Test for Events MVP
        decentNews.calculateReward();
    }

    function test_stakeFailWhenNotEnoughFunds() public{
        vm.expectRevert("Not enough funds");
        decentNews.stake();
    }

    function test_stakeWorksIfEnoughFunds() public{
        decentNews.stake{value: 0.05 ether}();
        assertEq(decentNews.isApproved(address(this)), true);
    }
}
contract DecentNewsTestAfterSuccessfulStake is Test {
    event rewardsCalculated(address indexed, int256);
    
    DecentNews public decentNews;

    function setUp() public {
        decentNews = new DecentNews();
        decentNews.stake{value: 0.05 ether}();
    }

    function test_publishArticle(bytes32 _hash) public {
       //@todo test for events
        decentNews.createArticle(_hash);
    }
    
    function test_reviewArticle() public {
        vm.expectRevert("No article available for review");
        decentNews.requestReview();
    }

    function test_submitVote(bool validArticle) public {
        vm.expectRevert("No article assigned");
        decentNews.submitVote(validArticle);
    }

    function test_calculateReward() public {
        //@todo Test for Events MVP
        decentNews.calculateReward();
    }
    
}

contract DecentNewsTestAfterSuccessfulStakeAndPublishedArticle is Test {
    event rewardsCalculated(address indexed, int256);
    
    DecentNews public decentNews;

    function setUp() public {
        decentNews = new DecentNews();
        decentNews.stake{value: 0.05 ether}();
        decentNews.createArticle(bytes32(uint(1)));
    }

    function test_publishArticle(bytes32 _hash) public {
       //@todo test for events
        decentNews.createArticle(_hash);
    }
    
    function test_reviewArticle() public {
        //@todo test for events
        decentNews.requestReview();
    }

    function test_submitVote(bool validArticle) public {
        vm.expectRevert("No article assigned");
        decentNews.submitVote(validArticle);
    }
    
    function test_calculateReward() public {
        //@todo Test for Events MVP
        decentNews.calculateReward();
    }
    
}

contract DecentNewsTestAfterSuccessfulStakeAndPublishedAndReviewRequestedArticle is Test {
    event rewardsCalculated(address indexed, int256);
    
    DecentNews public decentNews;

    function setUp() public {
        decentNews = new DecentNews();
        decentNews.stake{value: 0.05 ether}();
        decentNews.createArticle(bytes32(uint(1)));
        decentNews.requestReview();
    }

    function test_publishArticle(bytes32 _hash) public {
       //@todo test for events
        decentNews.createArticle(_hash);
    }
    
    function test_reviewArticle() public {
        vm.expectRevert("User already has review assigned");
        decentNews.requestReview();
    }

    function test_submitVote(bool validArticle) public {
        //@todo should work
        decentNews.submitVote(validArticle);
    }
    
    function test_calculateReward() public {
        //@todo Test for Events MVP
        decentNews.calculateReward();
    }
    
}

contract DecentNewsTestAfterTenReviews is Test {
    event rewardsCalculated(address indexed, int256);
    
    DecentNews public decentNews;

    function setUp() public {

        decentNews = new DecentNews();
        decentNews.stake{value: 0.05 ether}();
        decentNews.createArticle(bytes32(uint(1)));
        address[10] memory users = [
                address(0xE1),
                address(0xE2),
                address(0xE3),
                address(0xE4),
                address(0xE5),
                address(0xE6),
                address(0xE7),
                address(0xE8),
                address(0xE9),
                address(0xE10)
        ];
        // for(uint256 i; i < users.length; i++){
        //     hoax(users[i], 10 ether);
        // }
        //@todo add userList
        for(uint256 i; i < 3; i++){
            //vm.startPrank(users[i]); 
            //decentNews.stake{value: 0.05 ether}();
            decentNews.requestReview();
            decentNews.submitVote(true);
            //assertEq(decentNews.articleReviewState(bytes32(uint(1)))[score] == i);
            //vm.stopPrank();
        }
        
       
    }
    // function test_articleFinsished() public {
    //     //@todo test for event
    //     decentNews.withdraw(10);
    // }

    function test_publishArticle(bytes32 _hash) public {
       //@todo test for events
        decentNews.createArticle(_hash);
    }
    
    function test_reviewArticle() public {
        vm.expectRevert("No article available for review");
        decentNews.requestReview();
    }

    function test_submitVote(bool validArticle) public {
        //@todo should work
        vm.expectRevert("No article assigned");
        decentNews.submitVote(validArticle);
    }
    
    function test_calculateReward() public {
        //@todo Test for Events MVP
        decentNews.calculateReward();
    }
    
}