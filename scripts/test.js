const { ethers } = require('hardhat');
const abi = require('./etherbetsv2abi.json');

async function main(){
    
    const address = "0xF112660f6a6b3d86842c078fdf3826799671c257";
    const [signer] = await ethers.getSigners();

    const contract = new ethers.Contract(address, abi, signer); 
    console.log('Placing bets.');
    await contract.placeBet(3, {value: ethers.utils.parseEther("0.0001")}).catch((err) => { console.log(err)});
    await contract.placeBet(5, {value: ethers.utils.parseEther("0.0001")}).catch((err) => { console.log(err)});
    await contract.placeBet(6, {value: ethers.utils.parseEther("0.0001")}).catch((err) => { console.log(err)});
    console.log('Bets placed.');
    //await contract.beginDraw().catch((err) => { console.log(err)});
  }
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });