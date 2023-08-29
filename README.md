# ClaimsHatter

A Hats Protocol hatter contract enabling explicitly eligible wearers to claim a hat.

## Overview & Usage

In [Hats Protocol](https://github.com/hats-protocol/hats-protocol), hats are typically issued by admins minting them to wearers. While often that is the desired behavior, there are cases where it is desirable to allow wearers to claim a hat themselves, assuming they are eligible to wear them. ClaimsHatter enables DAOs to optionally make hats claimable by eligible wearers.

Making a hat claimable via ClaimsHatter involves the following steps:

0. Prerequisites and setup
1. Create a new instance of ClaimsHatter for the hat to claim
2. Mint or transfer an admin hat of the claimable hat to the ClaimsHatter instance from (1)
3. Eligible wearer(s) can now claim the hat

### Step 0: Prerequisites and setup

Making a hat claimable via ClaimsHatter includes a couple prerequisites.

First, the hat to claim must have an admin that can be worn by an instance of ClaimsHatter (see [Step 2](#step-2-mint-or-transfer-an-admin-hat-of-the-claimable-hat-to-the-claimshatter-instance)). In many cases, this will require creating an "extra" hat in between the hat to claim and what would otherwise be its admin hat.

For example, if in normal operations a hat tree would look like this...

```lua
   +-------------+
   | 1) Top Hat  |
   +-------------+
        |
   +---------------+
   | 1.1) Role Hat |
   +---------------+  
```

... then to make the Role Hat claimable, another hat needs to exist in between:

```lua
   +-------------+
   | 1) Top Hat  |
   +-------------+
        |
   +-----------------+
   | 1.1) Hatter Hat |
   +-----------------+
        |
   +---------------+
   | 1.2) Role Hat |
   +---------------+
```

Second, the hat to claim must have a [mechanistic eligibility module](https://github.com/Hats-Protocol/hats-protocol/#eligibility), i.e. one that implements the [IHatsEligibility](https://github.com/Hats-Protocol/hats-protocol/blob/main/src/Interfaces/IHatsEligibility.sol) interface. Only such modules can create the "explicit eligibility" that ClaimsHatter requires.

### Step 1: Create a new instance of ClaimsHatter for the hat to claim

New instances of ClaimsHatter are deployed via the [HatsModuleFactory](https://github.com/Hats-Protocol/hats-module/blob/main/src/HatsModuleFactory.sol), by using the `createHatsModule` function.
HatsModuleFactory is a clone factory that enables cheap creation of new module instances. The address of each instance is unique to the hat to claim (one ClaimsHatter per hat), and is deterministically generated.

Note that ClaimsHatter doesn't use initailization data or additional immutable arguments and so the `_otherImmutableArgs` and `_initData` parameters for the `createHatsModule` function should be empty.

### Step 2: Mint or transfer an admin hat of the claimable hat to the ClaimsHatter instance

ClaimsHatter is a "hatter" contract, which is a type of contract designed to wear an admin hat. When wearing an admin hat (such as the "Hatter Hat" in the second diagram above), it gains admin authorities over the child hat(s) below it (such as the "Role Hat"). In ClaimsHatter's case, this includes the ability to mint those hat(s).

To enable ClaimsHatter to mint hats, it must be wearing an admin hat of the hat to claim. This can be done by minting (or transferring, as relevant) the admin hat to the ClaimsHatter instance.

### Step 3: Claiming

Once steps 0-2 have been completed, explicitly eligible wearers can now claim the hat! They can do this simply by calling the `claim` function.

### Claiming on behalf of a wearer

In some cases, it may be desirable to allow a third party — such as a bot network — to claim a hat on behalf of a wearer. DAOs can optionally enable "claiming for" by calling the `enableClaimingFor` function.

Once enabled, anybody can then claim on behalf of an eligible wearer by calling the `claimFor` function, with the desired wearer as an argument.

## Development

This repo uses Foundry for development and testing. To get started:

1. Fork the project
2. Install [Foundry](https://book.getfoundry.sh/getting-started/installation)
3. To compile the contracts, run `forge build`
4. To test, run `forge test`
