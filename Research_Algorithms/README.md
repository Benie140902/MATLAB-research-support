The current folder is responsible for tunning either the algorithm that i have developed that is MMSE or gives suppport to modify the in built algorithms of 5G toolbox 
that is LSE. The one where real time IQ symbols are been collected from srsRAN and the function called nrChannelEstimate i have implemented ownChannelEstimate .
The lines that are present 
is the only line that are changed to make it compatible to MATLAB in built channel estimate.
Thus request for this repo can be made once want to test whether your algorithm is working fine for 5G IQ samples collected from srsRAN or any other opensource stacks.
Or else you can generate test vectors from srsRAN and check your algorithm is compatible to 5G standards if you lack in hardware using ch_sim_estimator code.
