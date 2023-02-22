# Parallel-Simulation-of-QPSK-and-QAM-with-simple-WhatsApp-GUI---MATLAB---Simulink
![image](https://user-images.githubusercontent.com/113800496/220714897-a9a77a46-7c39-4e37-b4d1-7925a411253e.png)
![image](https://user-images.githubusercontent.com/113800496/220714957-3384d068-6d1e-4079-b6fe-7b8a4299c83d.png)

# Running the Application
1. Clone the repository
2. Run the MATLAB file (it will automatically link to GUI and Simulink)
**Note that you may need to download some libraries for parallel simulation and maybe for the GUI**

This project consists of 3 main parts:
1. MATLAB code: finalProjectFunctionBased.m
2. MATLAB GUI: app2.mlapp
3. Simulink: cm_ldpc_decode_qpsk.slx and cm_ldpc_decode_qpsk_signal_final_trial.slx
The MATLAB code is linked to the GUI by passing some variables with assignin function and it runs the simulink in parallel using parsim function

# MATLAB code design

A typical communication system consists of:
1. Source Encoder
2. Channel Encoder
3. Modulator
4. Channel
5. Demodulator
6. Channel Decoder
7. Source Decoder

# Generalizing input (text - multiline, image and audio)

The main reason behind dealing with different inputs is because of the following procedure:
1. For **any** input, reshape it into 1-D array
2. Encode the given 1-D array with normal or Huffman encoding
3. Divide the new 1-D array into chunks of 58320 (64800*9/10) and fill the remaining bit of the last chunk with dummy ones
4. Send every couple of chunks into simulink with parsim by preparing inputs beforehand
**Note that number of chunks simulated in parallel depends on the number of cores in your pc**

9/10 is the LDPC rate used in Simulink

# Source Encoding & Decoding

Source Encoding and Decoding are of 2 types:
1. Normal with dec2bin and bin2dec
2. Huffman with huffmandict, huffmanenco and huffmandeco

*The code contains multiple bugs so it still needs testing for multiple edge cases but the main functionality is there*
