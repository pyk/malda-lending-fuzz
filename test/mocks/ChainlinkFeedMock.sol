// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract ChainlinkFeedMock {
    int256 answer;
    bool public isStale;

    constructor(int256 _initialPrice) {
        answer = _initialPrice;
        isStale = false;
    }

    function decimals() external pure returns (uint8) {
        return 8;
    }

    function latestAnswer() external view returns (int256) {
        return answer;
    }

    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 price,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        roundId = uint80(block.number);
        price = answer;
        startedAt = block.timestamp;
        answeredInRound = roundId;
        if (isStale) {
            updatedAt = 0;
        } else {
            updatedAt = block.timestamp;
        }
    }

    function updateAnswer(int256 newAnswer) external {
        answer = newAnswer;
    }

    function markAsStale() external {
        isStale = true;
    }
}
