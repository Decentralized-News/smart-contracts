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
