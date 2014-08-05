function [U, V] = IncrementalSNR(H,target_SNR_dB)
% Implementation of the incremental SNR algorithm with simplified pricing updates.
%
% Reference:
% Schmidt, D.A.; Utschick, W.; Honig, M.L., "Beamforming techniques for single-beam MIMO interference networks,"
% 2010 48th Annual Allerton Conference on Communication, Control, and Computing (Allerton),  pp.1182-1187, Sept. 29 2010 - Oct. 1 2010
% doi: 10.1109/ALLERTON.2010.5707048
%
% Not guaranteed to converge according to the following reference (where an improved version can be found):
% D. A. Schmidt, C. Shi, R. A. Berry, M. L. Honig, W. Utschick, "Comparison
% of distributed beamforming algorithms for MIMO interference networks,"
% IEEE Transactions on Signal Processing, vol. 61, no. 13, Jul. 2013.

nT=cellfun(@(x) size(x,2),H(1,:));
nR=cellfun(@(x) size(x,1),H(:,1));
K=size(H,1);

norm_diff=@(x,y) norm(x-y,'fro');

V=cell(K,1);
t=cell(K,1);
inv_X=cell(K,1);
sinr=zeros(K,1);
A=cell(K,1);

for us=1:K
    [~,~,G]=svd(H{us,us});
    V{us}=G(:,1); %Principal eigenvector of H{us,us}'*H{us,us}
end

target_SNR=10^(target_SNR_dB/10);
SNR_dB=0; %Initial SNR in dB
SNR=10^(SNR_dB/10); %Initial SNR in linear scale
NormTol=1e-4;
step_SNR_dB=4; %Step for SNR
factor_SNR=10^(step_SNR_dB/10);

while SNR < target_SNR
    while 1
        prev_V=V;
        for rx=1:K
            inv_X{rx}=inv_cov_int_noise_rx(rx,H,V,SNR);
            sinr(rx)=SINR(rx,H,V,inv_X);
            t{rx}=1/(sqrt(1+sinr(rx)))*inv_X{rx}*H{rx,rx}*V{rx};
        end
        for tx=1:K
            A{tx}=matrix_A(tx,H,t,inv_X,sinr);
            [F, E] = eig(A{tx});
            [E,idx]=sort(real(diag(E)),'descend');
            F=F(:,idx);
            V{tx}=F(:,1);
        end
        
        if all(cellfun(norm_diff,prev_V,V)<NormTol)
            break;
        end
    end
    SNR=SNR*factor_SNR;
end

%% Compute MMSE decoders
W=cell(K,1);
noise_var=10^(-target_SNR_dB/10); %Noise variance at each antenna
for rx=1:K
    W{rx}=noise_var*eye(nR(rx));
end
options.W=W;
U=ComputeDecoders(H,V,eye(K),'MMSE',options);

end


%% Function to compute the inverse of the interference+noise covariance matrix at the receiver rx
function X = inv_cov_int_noise_rx(rx,H,V,SNR)
nR=cellfun(@(x) size(x,1),H(:,1));
K=size(H,1);
X=0;
for tx=[1:rx-1 rx+1:K]
    X = X+ H{rx,tx}*V{tx}*V{tx}'*H{rx,tx}';
end
X=X+(1/SNR*eye(nR(rx)));
X=pinv(X);
end


function sinr = SINR(rx,H,V,inv_X)
sinr= real(V{rx}'*H{rx,rx}'*inv_X{rx}*H{rx,rx}*V{rx});
end

function A=matrix_A(tx,H,t,inv_X,sinr)
K=size(H,1);
temp=0;
for rx=[1:tx-1 tx+1:K]
    temp=temp+H{rx,tx}'*t{rx}*t{rx}'*H{rx,tx};
end
A= (1/(1+sinr(tx)))*H{tx,tx}'*inv_X{tx}*H{tx,tx}-temp;
end
