// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {SubscriptionPaymentStorage} from "./SubscriptionPaymentStorage.sol";

interface ISubscriptionPayment {
    event SetPlan(uint256 planType, uint256 monthlyFee, uint256 yearlyFee);
    event Subscribe(
        address indexed user,
        uint256 planType,
        uint256 expiry,
        bool autoRenewEnabled
    );
    event ExtendSubscription(
        address indexed user,
        uint256 planType,
        uint256 expiry
    );

    function getPlans()
        external
        view
        returns (SubscriptionPaymentStorage.Plan[] memory);

    function subscribe(
        bytes32 subscriptionPeriod,
        uint256 planType,
        bool autoRenewEnabled
    ) external;

    function extendSubscription(
        address user,
        bytes32 subscriptionPeriod,
        uint256 planType
    ) external;

    function enableAutoRenew(address user, uint256 planType) external;

    function disableAutoRenew(address user, uint256 planType) external;
}
