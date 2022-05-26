Write the voting smart contract
When we ran the migration, we learned that writing to the blockchain has some costs. With that in mind, deploying a smart contract full of bugs could result in unplanned investment from our side — not only the time and energy needed to fix bugs, but actual fees too. To reduce the risk of bugs, we would want to write several tests for the smart contract, though this tutorial won't cover that topic. Testing itself could fill several standalone tutorials.

So let's jump right in and create the voting contract. The Truffle CLI tool is helping us with some utility commands to make development easier. To create the "Voting" contract, run truffle create contract Voting within the initialized project directory.

The truffle create command created a new file in the contracts directory, called "Voting.sol":

// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

contract Voting {
  constructor() public {
  }
}

Depending on your truffle version, the content may look slightly different.

In this smart contract, we want to allow every user to place three votes. These votes don't need to be unique; the users can vote three times on the same movie if they want to. To limit the number of maximum votes, introduce a new constant within the contract block, uint public constant MAX_VOTES_PER_VOTER = 3;. Later on, we will use this contract to check if the user reached the maximum available votes or not.

While still within the contract block, now it’s time to define the structure of movies. From a voting point of view, we don't care about when the movie was released or who directed it. We only need an ID, a title, and the number of votes placed on the movie. To let the users identify the movie easier, we will use a cover image too — some of us are more visually oriented:

// [...]

contract Voting {
  uint public constant MAX_VOTES_PER_VOTER = 3;

  struct Movie {
    uint id;
    string title;
    string cover;
    uint votes;
  }
}

Since we already know what we want to do, let's think about the user experience for a bit. Wouldn't it be great if we could notify the user when a new movie is added to the blockchain? Of course it would! Thankfully Solidity gives us building blocks, called “events.” Smart Contracts can emit these events, and dApps can listen to them. We define two events: Voted and NewMovie.

// [...]

  struct Movie {
    uint id;
    string title;
    string cover;
    uint votes;
  }

  event Voted ();
  event NewMovie ();

// [...]

Although the events can receive arguments, we won't define any. In our use case, we don't need to differentiate between votes, nor do we want to know who added which movie. After defining the events, go on and define a getter for movies and votes.

// [...]

  event NewMovie ();
  event Voted ();

  mapping(uint => Movie) public movies;
  uint public moviesCount;

  mapping(address => uint) public votes;

  constructor() {
    moviesCount = 0;
  }

// [...]
Mappings are key-value data structures. For movies, we bind a number to every movie, where the number represents the ID of the given movie. However, in the case of votes, we bind a wallet address to a number. This number stands for the number of votes placed from a single wallet.

You may wonder what moviesCount is then. That counter keeps track of how many movies have been added. It is also used to know which movie ID is next. Therefore, we begin with the moviesCount at zero.

Next, we must define the voting function, the core function of this smart contract. Define the voting function by deploying the following commands:

// [...]

  function vote(uint _movieID) public {
    require(votes[msg.sender] < MAX_VOTES_PER_VOTER, "Voter has no votes left.");
    require(_movieID > 0 && _movieID <= moviesCount, "Movie ID is out of range.");

    votes[msg.sender]++;
    movies[_movieID].votes++;

    emit Voted();
  }

// [...]

The responsibilities of this function are to check if the user can place a vote on an existing movie, increment the voting counters, and emit the Voted event. Although this function is simple, I would like to mention one special part: msg.sender. Smart contracts have some built-in global variables and msg is one of them. This variable allows access to the message received by the smart contract. msg.sender represents the address that is called by the contract.

Now the only thing left to do is to implement a way we can add new movies. Deploy the following commands to define the addMovie function:

// [...]

  function addMovie(string memory _title, string memory _cover) public {
    moviesCount++;

    Movie memory movie = Movie(moviesCount, _title, _cover, 0);
    movies[moviesCount] = movie;

    emit NewMovie();
    vote(moviesCount);
  }
}  // closing the contract block

Although we originally used moviesCount in the vote function, here you can see its real value. The movies mapping key represents the ID of the movie, and we keep track of the latest ID globally using the moviesCount.

That's it, the smart contract is done! But now we need to interact with it somehow.