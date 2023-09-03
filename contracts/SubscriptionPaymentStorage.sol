// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

contract SubscriptionPaymentStorage {
    IERC20Upgradeable public feeToken;
    uint256 public constant MONTH_IN_SECONDS = 2592000; // 30 days
    uint256 public constant YEAR_IN_SECONDS = 31536000; // 365 days

    struct Plan {
        uint256 planType;
        uint256 monthlyFee;
        uint256 yearlyFee;
    }

    struct Subscription {
        bytes32 subscriptionPeriod;
        uint256 planType;
        uint256 expiry;
        bool autoRenewEnabled;
    }

    mapping(uint256 => Plan) public plans;

    mapping(address => mapping(uint256 => Subscription))
        public userSubscriptions;
}
