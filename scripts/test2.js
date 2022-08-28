const { ethers } = require('hardhat');
const abi = require('./etherbetsv2abi.json');
const pk = require('../hardhat.config.js').networks.goerli.accounts[0];
const pk2 = require('../hardhat.config.js').networks.goerli.accounts[1];
const url = require('../hardhat.config.js').networks.goerli.url;

const generateCombinations = require('./combinations');
function arrToUint(arr) {
  n = 0;
  for (let i = 0; i < arr.length; i++) {
    n |= (1 << (arr[i] - 1));
  }
  return n;
}

// Test for lottery with 8 numbers, 2 getting picked.

async function main() {

  const combinations = generateCombinations(Array.from({ length: 8 }, (_, i) => i + 1), 2);
  const address = "0x3691f6887064084ab870bc343DeBDfC4E6206DDd";
  const provider = ethers.getDefaultProvider(url);
  const signer = new ethers.Wallet(pk, provider);
  const signer2 = new ethers.Wallet(pk2, provider);

  const contract = new ethers.Contract(address, abi, signer);
  const contract2 = new ethers.Contract(address, abi, signer2);
  console.log('Placing bets.');
  for (let i = 0; i < 3; i++) {
    for (const c of combinations) {
      if (Math.floor(Math.random() * 10) % 2 == 0) {
        await contract.placeBet(arrToUint(c), { value: ethers.utils.parseEther("0.0001") }).catch((err) => { console.log(err) });
      }
      else {
        await contract2.placeBet(arrToUint(c), { value: ethers.utils.parseEther("0.0001") }).catch((err) => { console.log(err) });
      }
    }
  }
  console.log('Bets placed.');
  //await contract.beginDraw().catch((err) => { console.log(err)});
}
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });