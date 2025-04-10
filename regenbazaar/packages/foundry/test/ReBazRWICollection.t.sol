// Add fuzz testing
function testFuzzMint(uint256 amount) public {
    vm.assume(amount > 0.1 ether && amount < 100 ether);
    // ... test logic
}

// Add edge case testing
function testMaxSupplyReached() public {
    // Mint up to maxSupply
    for (uint256 i = 0; i < tierMaxSupplies[0]; i++) {
        vm.prank(user1);
        collection.mint{ value: 0.1 ether }(1);
    }

    // Try to mint one more
    vm.prank(user2);
    vm.expectRevert("Tier sold out");
    collection.mint{ value: 0.1 ether }(1);
}
