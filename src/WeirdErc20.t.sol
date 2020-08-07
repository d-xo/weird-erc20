pragma solidity ^0.6.7;

import "ds-test/test.sol";

import "./WeirdErc20.sol";

contract WeirdErc20Test is DSTest {
    WeirdErc20 erc;

    function setUp() public {
        erc = new WeirdErc20();
    }

    function testFail_basic_sanity() public {
        assertTrue(false);
    }

    function test_basic_sanity() public {
        assertTrue(true);
    }
}
