#include <stddef.h>
#include "../../model_gpu_utils.h"

#include "mixed_tentusscher_myo_epi_2004_S2_5.h"

extern "C" SET_ODE_INITIAL_CONDITIONS_GPU(set_model_initial_conditions_gpu) {

    log_to_stdout_and_file("Using mixed version of TT3 (MCELL + EPI) GPU model\n");

    uint32_t num_volumes = solver->original_num_cells;

    // execution configuration
    const int GRID  = (num_volumes + BLOCK_SIZE - 1)/BLOCK_SIZE;

    size_t size = num_volumes*sizeof(real);
    size_t extra_data_bytes_size = num_volumes*sizeof(uint32_t);

    // TODO: Think what to do when the number of equations are different between the cellular models ...
    check_cuda_error(cudaMallocPitch((void **) &(solver->sv), &pitch_h, size, (size_t )NEQ));
    check_cuda_error(cudaMemcpyToSymbol(pitch, &pitch_h, sizeof(size_t)));

    // Get the mapping array
    uint32_t *mapping = NULL;
    uint32_t *mapping_device = NULL;
    if(solver->ode_extra_data) {
        mapping = (uint32_t*)(solver->ode_extra_data);
        check_cuda_error(cudaMalloc((void **)&mapping_device, extra_data_bytes_size));
        check_cuda_error(cudaMemcpy(mapping_device, mapping, extra_data_bytes_size, cudaMemcpyHostToDevice));
    }
    else {
        log_to_stderr_and_file_and_exit("You need to specify a mask function when using a mixed model!\n");
    }

    kernel_set_model_inital_conditions <<<GRID, BLOCK_SIZE>>>(solver->sv, NULL, mapping_device, num_volumes);

    check_cuda_error( cudaPeekAtLastError() );
    cudaDeviceSynchronize();
    return pitch_h;

}

extern "C" SOLVE_MODEL_ODES(solve_model_odes_gpu) {

    size_t num_cells_to_solve = ode_solver->num_cells_to_solve;
    uint32_t * cells_to_solve = ode_solver->cells_to_solve;
    real *sv = ode_solver->sv;
    real dt = ode_solver->min_dt;
    uint32_t num_steps = ode_solver->num_steps;

    // execution configuration
    const int GRID  = ((int)num_cells_to_solve + BLOCK_SIZE - 1)/BLOCK_SIZE;

    size_t stim_currents_size = sizeof(real)*num_cells_to_solve;
    size_t cells_to_solve_size = sizeof(uint32_t)*num_cells_to_solve;

    real *stims_currents_device;
    check_cuda_error(cudaMalloc((void **) &stims_currents_device, stim_currents_size));
    check_cuda_error(cudaMemcpy(stims_currents_device, stim_currents, stim_currents_size, cudaMemcpyHostToDevice));

    uint32_t *cells_to_solve_device = NULL;
    if(cells_to_solve != NULL) {
        check_cuda_error(cudaMalloc((void **) &cells_to_solve_device, cells_to_solve_size));
        check_cuda_error(cudaMemcpy(cells_to_solve_device, cells_to_solve, cells_to_solve_size, cudaMemcpyHostToDevice));
    }

    // Get the mapping array
    uint32_t *mapping = NULL, *mapping_device = NULL;
    if (ode_solver->ode_extra_data) {
        mapping = (uint32_t*)(ode_solver->ode_extra_data);
        check_cuda_error(cudaMalloc((void **)&mapping_device, cells_to_solve_size));
        check_cuda_error(cudaMemcpy(mapping_device, mapping, cells_to_solve_size, cudaMemcpyHostToDevice));
    }
    else {
        log_to_stderr_and_file_and_exit("You need to specify a mask function when using a mixed model!\n");
    }

    solve_gpu<<<GRID, BLOCK_SIZE>>>(dt, sv, stims_currents_device, cells_to_solve_device, num_cells_to_solve, num_steps, mapping_device);

    check_cuda_error( cudaPeekAtLastError() );

    check_cuda_error(cudaFree(stims_currents_device));
    if(cells_to_solve_device) check_cuda_error(cudaFree(cells_to_solve_device));
    if(mapping_device) check_cuda_error(cudaFree(mapping_device));

}

__global__ void kernel_set_model_inital_conditions(real *sv, real *IC, uint32_t *mapping, int num_volumes) {

    int threadID = blockDim.x * blockIdx.x + threadIdx.x;

    if (threadID < num_volumes) {
        
        // MCELL
        if (mapping[threadID] == 0) {

            // Elnaz's steady-state initial conditions
            real sv_sst[]={-86.3965119057144,0.00133824305081220,0.775463576993407,0.775278393595599,0.000179499343643571,0.483303039835057,0.00297647859235379,0.999998290403642,1.98961879737287e-08,1.93486789479597e-05,0.999599147019885,1.00646342475688,0.999975178010127,5.97703651642618e-05,0.418325344820368,10.7429775420171,138.918155900633};
            for (uint32_t i = 0; i < NEQ; i++)
                *((real * )((char *) sv + pitch * i) + threadID) = sv_sst[i];
        }
        // EPI
        else if (mapping[threadID] == 1) {

            // Elnaz's steady-state initial conditions
            real sv_sst[]={ -86.5180103766650, 0.00130403507538545, 0.778471794824763, 0.778283525838093, 0.000176065618651399, 0.484567171933683, 0.00295084416213736, 0.999998331387518, 1.94976417188725e-08, 1.90377881905604e-05, 0.999769816140066, 1.00765120153943, 0.999999421011808, 3.19432158740013e-05, 1.25705353770675, 9.77685728583073, 139.479930314946 };
            for (uint32_t i = 0; i < NEQ; i++)
                *((real * )((char *) sv + pitch * i) + threadID) = sv_sst[i];
        }
    }
}

// Solving the model for each cell in the tissue matrix ni x nj
__global__ void solve_gpu(real dt, real *sv, real* stim_currents,
                          uint32_t *cells_to_solve, uint32_t num_cells_to_solve,
                          int num_steps,
                          uint32_t *mapping) {

    int threadID = blockDim.x * blockIdx.x + threadIdx.x;
    int sv_id;

    // Each thread solves one cell 
    if(threadID < num_cells_to_solve) {

        if(cells_to_solve)
            sv_id = cells_to_solve[threadID];
        else
            sv_id = threadID;

        real rDY[NEQ];

        for (int n = 0; n < num_steps; ++n) {

            // MCELL
            if (mapping[sv_id] == 0) {

                RHS_gpu_myo(sv, rDY, stim_currents[threadID], sv_id, dt);

                for(int i = 0; i < NEQ; i++) {
                    *((real*)((char*)sv + pitch * i) + sv_id) = rDY[i];
                }
            }
            // EPI
            else if (mapping[sv_id] == 1) {

                RHS_gpu_epi(sv, rDY, stim_currents[threadID], sv_id, dt);

                for(int i = 0; i < NEQ; i++) {
                    *((real*)((char*)sv + pitch * i) + sv_id) = rDY[i];
                }
            }
        }
    }
}

inline __device__ void RHS_gpu_myo (real *sv, real *rDY_, real stim_current, int threadID_, real dt) {

    // State variables
    real svolt = *((real*)((char*)sv + pitch * 0) + threadID_);
    real sm    = *((real*)((char*)sv + pitch * 1) + threadID_);
    real sh    = *((real*)((char*)sv + pitch * 2) + threadID_);
    real sj    = *((real*)((char*)sv + pitch * 3) + threadID_);
    real sxr1  = *((real*)((char*)sv + pitch * 4) + threadID_);
    real sxr2  = *((real*)((char*)sv + pitch * 5) + threadID_);
    real sxs   = *((real*)((char*)sv + pitch * 6) + threadID_);
    real ss    = *((real*)((char*)sv + pitch * 7) + threadID_);
    real sr    = *((real*)((char*)sv + pitch * 8) + threadID_);
    real sd    = *((real*)((char*)sv + pitch * 9) + threadID_);
    real sf    = *((real*)((char*)sv + pitch * 10) + threadID_);
    real sfca  = *((real*)((char*)sv + pitch * 11) + threadID_);
    real sg    = *((real*)((char*)sv + pitch * 12) + threadID_);
    real Cai   = *((real*)((char*)sv + pitch * 13) + threadID_);
    real CaSR  = *((real*)((char*)sv + pitch * 14) + threadID_);
    real Nai   = *((real*)((char*)sv + pitch * 15) + threadID_);
    real Ki    = *((real*)((char*)sv + pitch * 16) + threadID_);

    //External concentrations
    real Ko=5.4;
    real Cao=2.0;
    real Nao=140.0;

    //Intracellular volumes
    real Vc=0.016404;
    real Vsr=0.001094;

    //Calcium dynamics
    real Bufc=0.15f;
    real Kbufc=0.001f;
    real Bufsr=10.f;
    real Kbufsr=0.3f;
    real taufca=2.f;
    real taug=2.f;
    real Vmaxup=0.000425f;
    real Kup=0.00025f;

    //Constants
    const real R = 8314.472f;
    const real F = 96485.3415f;
    const real T =310.0f;
    real RTONF   =(R*T)/F;

    //Cellular capacitance         
    real CAPACITANCE=0.185;

    //Parameters for currents
    //Parameters for IKr
    real Gkr=0.096;
    //Parameters for Iks
    real pKNa=0.03;

// [!] Myocardium cell
    real Gks=0.062;
//Parameters for Ik1
    real GK1=5.405;
//Parameters for Ito
// [!] Myocardium cell
    real Gto=0.294;
//Parameters for INa
    real GNa=14.838;
//Parameters for IbNa
    real GbNa=0.00029;
//Parameters for INaK
    real KmK=1.0;
    real KmNa=40.0;
    real knak=1.362;
//Parameters for ICaL
    real GCaL=0.000175;
//Parameters for IbCa
    real GbCa=0.000592;
//Parameters for INaCa
    real knaca=1000;
    real KmNai=87.5;
    real KmCa=1.38;
    real ksat=0.1;
    real n=0.35;
//Parameters for IpCa
    real GpCa=0.825;
    real KpCa=0.0005;
//Parameters for IpK;
    real GpK=0.0146;


    real IKr;
    real IKs;
    real IK1;
    real Ito;
    real INa;
    real IbNa;
    real ICaL;
    real IbCa;
    real INaCa;
    real IpCa;
    real IpK;
    real INaK;
    real Irel;
    real Ileak;


    real dNai;
    real dKi;
    real dCai;
    real dCaSR;

    real A;
//    real BufferFactorc;
//    real BufferFactorsr;
    real SERCA;
    real Caisquare;
    real CaSRsquare;
    real CaCurrent;
    real CaSRCurrent;


    real fcaold;
    real gold;
    real Ek;
    real Ena;
    real Eks;
    real Eca;
    real CaCSQN;
    real bjsr;
    real cjsr;
    real CaBuf;
    real bc;
    real cc;
    real Ak1;
    real Bk1;
    real rec_iK1;
    real rec_ipK;
    real rec_iNaK;
    real AM;
    real BM;
    real AH_1;
    real BH_1;
    real AH_2;
    real BH_2;
    real AJ_1;
    real BJ_1;
    real AJ_2;
    real BJ_2;
    real M_INF;
    real H_INF;
    real J_INF;
    real TAU_M;
    real TAU_H;
    real TAU_J;
    real axr1;
    real bxr1;
    real axr2;
    real bxr2;
    real Xr1_INF;
    real Xr2_INF;
    real TAU_Xr1;
    real TAU_Xr2;
    real Axs;
    real Bxs;
    real Xs_INF;
    real TAU_Xs;
    real R_INF;
    real TAU_R;
    real S_INF;
    real TAU_S;
    real Ad;
    real Bd;
    real Cd;
    real TAU_D;
    real D_INF;
    real TAU_F;
    real F_INF;
    real FCa_INF;
    real G_INF;

    real inverseVcF2=1/(2*Vc*F);
    real inverseVcF=1./(Vc*F);
    real Kupsquare=Kup*Kup;
//    real BufcKbufc=Bufc*Kbufc;
//    real Kbufcsquare=Kbufc*Kbufc;
//    real Kbufc2=2*Kbufc;
//    real BufsrKbufsr=Bufsr*Kbufsr;
//    const real Kbufsrsquare=Kbufsr*Kbufsr;
//    const real Kbufsr2=2*Kbufsr;
    const real exptaufca=exp(-dt/taufca);
    const real exptaug=exp(-dt/taug);

    real sItot;

    //Needed to compute currents
    Ek=RTONF*(log((Ko/Ki)));
    Ena=RTONF*(log((Nao/Nai)));
    Eks=RTONF*(log((Ko+pKNa*Nao)/(Ki+pKNa*Nai)));
    Eca=0.5*RTONF*(log((Cao/Cai)));
    Ak1=0.1/(1.+exp(0.06*(svolt-Ek-200)));
    Bk1=(3.*exp(0.0002*(svolt-Ek+100))+
         exp(0.1*(svolt-Ek-10)))/(1.+exp(-0.5*(svolt-Ek)));
    rec_iK1=Ak1/(Ak1+Bk1);
    rec_iNaK=(1./(1.+0.1245*exp(-0.1*svolt*F/(R*T))+0.0353*exp(-svolt*F/(R*T))));
    rec_ipK=1./(1.+exp((25-svolt)/5.98));


    //Compute currents
    INa=GNa*sm*sm*sm*sh*sj*(svolt-Ena);
    ICaL=GCaL*sd*sf*sfca*4*svolt*(F*F/(R*T))*
         (exp(2*svolt*F/(R*T))*Cai-0.341*Cao)/(exp(2*svolt*F/(R*T))-1.);
    Ito=Gto*sr*ss*(svolt-Ek);
    IKr=Gkr*sqrt(Ko/5.4)*sxr1*sxr2*(svolt-Ek);
    IKs=Gks*sxs*sxs*(svolt-Eks);
    IK1=GK1*rec_iK1*(svolt-Ek);
    INaCa=knaca*(1./(KmNai*KmNai*KmNai+Nao*Nao*Nao))*(1./(KmCa+Cao))*
          (1./(1+ksat*exp((n-1)*svolt*F/(R*T))))*
          (exp(n*svolt*F/(R*T))*Nai*Nai*Nai*Cao-
           exp((n-1)*svolt*F/(R*T))*Nao*Nao*Nao*Cai*2.5);
    INaK=knak*(Ko/(Ko+KmK))*(Nai/(Nai+KmNa))*rec_iNaK;
    IpCa=GpCa*Cai/(KpCa+Cai);
    IpK=GpK*rec_ipK*(svolt-Ek);
    IbNa=GbNa*(svolt-Ena);
    IbCa=GbCa*(svolt-Eca);


    //Determine total current
    (sItot) = IKr    +
              IKs   +
              IK1   +
              Ito   +
              INa   +
              IbNa  +
              ICaL  +
              IbCa  +
              INaK  +
              INaCa +
              IpCa  +
              IpK   +
              stim_current;


    //update concentrations
    Caisquare=Cai*Cai;
    CaSRsquare=CaSR*CaSR;
    CaCurrent=-(ICaL+IbCa+IpCa-2.0f*INaCa)*inverseVcF2*CAPACITANCE;
    A=0.016464f*CaSRsquare/(0.0625f+CaSRsquare)+0.008232f;
    Irel=A*sd*sg;
    Ileak=0.00008f*(CaSR-Cai);
    SERCA=Vmaxup/(1.f+(Kupsquare/Caisquare));
    CaSRCurrent=SERCA-Irel-Ileak;
    CaCSQN=Bufsr*CaSR/(CaSR+Kbufsr);
    dCaSR=dt*(Vc/Vsr)*CaSRCurrent;
    bjsr=Bufsr-CaCSQN-dCaSR-CaSR+Kbufsr;
    cjsr=Kbufsr*(CaCSQN+dCaSR+CaSR);
    CaSR=(sqrt(bjsr*bjsr+4.*cjsr)-bjsr)/2.;
    CaBuf=Bufc*Cai/(Cai+Kbufc);
    dCai=dt*(CaCurrent-CaSRCurrent);
    bc=Bufc-CaBuf-dCai-Cai+Kbufc;
    cc=Kbufc*(CaBuf+dCai+Cai);
    Cai=(sqrt(bc*bc+4*cc)-bc)/2;



    dNai=-(INa+IbNa+3*INaK+3*INaCa)*inverseVcF*CAPACITANCE;
    Nai+=dt*dNai;

    dKi=-(stim_current+IK1+Ito+IKr+IKs-2*INaK+IpK)*inverseVcF*CAPACITANCE;
    Ki+=dt*dKi;

    //compute steady state values and time constants
    AM=1./(1.+exp((-60.-svolt)/5.));
    BM=0.1/(1.+exp((svolt+35.)/5.))+0.10/(1.+exp((svolt-50.)/200.));
    TAU_M=AM*BM;
    M_INF=1./((1.+exp((-56.86-svolt)/9.03))*(1.+exp((-56.86-svolt)/9.03)));
    if (svolt>=-40.)
    {
        AH_1=0.;
        BH_1=(0.77/(0.13*(1.+exp(-(svolt+10.66)/11.1))));
        TAU_H= 1.0/(AH_1+BH_1);
    }
    else
    {
        AH_2=(0.057*exp(-(svolt+80.)/6.8));
        BH_2=(2.7*exp(0.079*svolt)+(3.1e5)*exp(0.3485*svolt));
        TAU_H=1.0/(AH_2+BH_2);
    }
    H_INF=1./((1.+exp((svolt+71.55)/7.43))*(1.+exp((svolt+71.55)/7.43)));
    if(svolt>=-40.)
    {
        AJ_1=0.;
        BJ_1=(0.6*exp((0.057)*svolt)/(1.+exp(-0.1*(svolt+32.))));
        TAU_J= 1.0/(AJ_1+BJ_1);
    }
    else
    {
        AJ_2=(((-2.5428e4)*exp(0.2444*svolt)-(6.948e-6)*
                                             exp(-0.04391*svolt))*(svolt+37.78)/
              (1.+exp(0.311*(svolt+79.23))));
        BJ_2=(0.02424*exp(-0.01052*svolt)/(1.+exp(-0.1378*(svolt+40.14))));
        TAU_J= 1.0/(AJ_2+BJ_2);
    }
    J_INF=H_INF;

    Xr1_INF=1./(1.+exp((-26.-svolt)/7.));
    axr1=450./(1.+exp((-45.-svolt)/10.));
    bxr1=6./(1.+exp((svolt-(-30.))/11.5));
    TAU_Xr1=axr1*bxr1;
    Xr2_INF=1./(1.+exp((svolt-(-88.))/24.));
    axr2=3./(1.+exp((-60.-svolt)/20.));
    bxr2=1.12/(1.+exp((svolt-60.)/20.));
    TAU_Xr2=axr2*bxr2;

    Xs_INF=1./(1.+exp((-5.-svolt)/14.));
    Axs=1100./(sqrt(1.+exp((-10.-svolt)/6)));
    Bxs=1./(1.+exp((svolt-60.)/20.));
    TAU_Xs=Axs*Bxs;

// [!] Myocardium cell
    R_INF=1./(1.+exp((20-svolt)/6.));
    S_INF=1./(1.+exp((svolt+20)/5.));
    TAU_R=9.5*exp(-(svolt+40.)*(svolt+40.)/1800.)+0.8;
    TAU_S=85.*exp(-(svolt+45.)*(svolt+45.)/320.)+5./(1.+exp((svolt-20.)/5.))+3.;


    D_INF=1./(1.+exp((-5-svolt)/7.5));
    Ad=1.4/(1.+exp((-35-svolt)/13))+0.25;
    Bd=1.4/(1.+exp((svolt+5)/5));
    Cd=1./(1.+exp((50-svolt)/20));
    TAU_D=Ad*Bd+Cd;
    F_INF=1./(1.+exp((svolt+20)/7));
    //TAU_F=1125*exp(-(svolt+27)*(svolt+27)/300)+80+165/(1.+exp((25-svolt)/10));
    TAU_F=1125*exp(-(svolt+27)*(svolt+27)/240)+80+165/(1.+exp((25-svolt)/10));      // Updated from CellML


    FCa_INF=(1./(1.+pow((Cai/0.000325),8))+
             0.1/(1.+exp((Cai-0.0005)/0.0001))+
             0.20/(1.+exp((Cai-0.00075)/0.0008))+
             0.23 )/1.46;
    if(Cai<0.00035)
        G_INF=1./(1.+pow((Cai/0.00035),6));
    else
        G_INF=1./(1.+pow((Cai/0.00035),16));

    //Update gates
    rDY_[1]  = M_INF-(M_INF-sm)*exp(-dt/TAU_M);
    rDY_[2]  = H_INF-(H_INF-sh)*exp(-dt/TAU_H);
    rDY_[3]  = J_INF-(J_INF-sj)*exp(-dt/TAU_J);
    rDY_[4]  = Xr1_INF-(Xr1_INF-sxr1)*exp(-dt/TAU_Xr1);
    rDY_[5]  = Xr2_INF-(Xr2_INF-sxr2)*exp(-dt/TAU_Xr2);
    rDY_[6]  = Xs_INF-(Xs_INF-sxs)*exp(-dt/TAU_Xs);
    rDY_[7]  = S_INF-(S_INF-ss)*exp(-dt/TAU_S);
    rDY_[8]  = R_INF-(R_INF-sr)*exp(-dt/TAU_R);
    rDY_[9]  = D_INF-(D_INF-sd)*exp(-dt/TAU_D);
    rDY_[10] = F_INF-(F_INF-sf)*exp(-dt/TAU_F);
    fcaold= sfca;
    sfca = FCa_INF-(FCa_INF-sfca)*exptaufca;
    if(sfca>fcaold && (svolt)>-37.0)
        sfca = fcaold;
    gold = sg;
    sg = G_INF-(G_INF-sg)*exptaug;

    if(sg>gold && (svolt)>-37.0)
        sg=gold;

    //update voltage
    rDY_[0] = svolt + dt*(-sItot);
    rDY_[11] = sfca;
    rDY_[12] = sg;
    rDY_[13] = Cai;
    rDY_[14] = CaSR;
    rDY_[15] = Nai;
    rDY_[16] = Ki;

}

inline __device__ void RHS_gpu_epi (real *sv, real *rDY_, real stim_current, int threadID_, real dt) {

    // Changed parameters
    real parameters []={ 14.0425347024085, 0.000535677026211757, 0.000165310108418668, 0.000350622775813131, 0.284242546174007, 0.160699932744295, 0.199053804511766, 4.02983501857037, 0.0207339018842815, 1.90362917367254, 1092.38391918131, 0.000589746455166102, 0.152476943428258, 0.0199994247147465, 0.00594175101819478, 9.05890620616966e-06 };

    // State variables
    real svolt = *((real*)((char*)sv + pitch * 0) + threadID_);
    real sm    = *((real*)((char*)sv + pitch * 1) + threadID_);
    real sh    = *((real*)((char*)sv + pitch * 2) + threadID_);
    real sj    = *((real*)((char*)sv + pitch * 3) + threadID_);
    real sxr1  = *((real*)((char*)sv + pitch * 4) + threadID_);
    real sxr2  = *((real*)((char*)sv + pitch * 5) + threadID_);
    real sxs   = *((real*)((char*)sv + pitch * 6) + threadID_);
    real ss    = *((real*)((char*)sv + pitch * 7) + threadID_);
    real sr    = *((real*)((char*)sv + pitch * 8) + threadID_);
    real sd    = *((real*)((char*)sv + pitch * 9) + threadID_);
    real sf    = *((real*)((char*)sv + pitch * 10) + threadID_);
    real sfca  = *((real*)((char*)sv + pitch * 11) + threadID_);
    real sg    = *((real*)((char*)sv + pitch * 12) + threadID_);
    real Cai   = *((real*)((char*)sv + pitch * 13) + threadID_);
    real CaSR  = *((real*)((char*)sv + pitch * 14) + threadID_);
    real Nai   = *((real*)((char*)sv + pitch * 15) + threadID_);
    real Ki    = *((real*)((char*)sv + pitch * 16) + threadID_);

    //External concentrations
    real Ko=5.4;
    real Cao=2.0;
    real Nao=140.0;

    //Intracellular volumes
    real Vc=0.016404;
    real Vsr=0.001094;

    //Calcium dynamics
    real Bufc=0.15f;
    real Kbufc=0.001f;
    real Bufsr=10.f;
    real Kbufsr=0.3f;
    real taufca=2.f;
    real taug=2.f;
    real Vmaxup=0.000425f;
    real Kup=0.00025f;

    //Constants
    const real R = 8314.472f;
    const real F = 96485.3415f;
    const real T =310.0f;
    real RTONF   =(R*T)/F;

    //Cellular capacitance         
    real CAPACITANCE=0.185;

    //Parameters for currents
    //Parameters for IKr
    real Gkr=0.096;
    //Parameters for Iks
    real pKNa=0.03;
    // [!] Epicardium cell
    real Gks=0.245;
    //Parameters for Ik1
    real GK1=5.405;
    //Parameters for Ito
// [!] Epicardium cell
    real Gto=0.294;
//Parameters for INa
    real GNa=14.838;
//Parameters for IbNa
    real GbNa=0.00029;
//Parameters for INaK
    real KmK=1.0;
    real KmNa=40.0;
    real knak=1.362;
//Parameters for ICaL
    real GCaL=0.000175;
//Parameters for IbCa
    real GbCa=0.000592;
//Parameters for INaCa
    real knaca=1000;
    real KmNai=87.5;
    real KmCa=1.38;
    real ksat=0.1;
    real n=0.35;
//Parameters for IpCa
    real GpCa=0.825;
    real KpCa=0.0005;
//Parameters for IpK;
    real GpK=0.0146;

    GNa=parameters[0];
    GbNa=parameters[1];
    GCaL=parameters[2];
    GbCa=parameters[3];
    Gto=parameters[4];
    Gkr=parameters[5];
    Gks=parameters[6];
    GK1=parameters[7];
    GpK=parameters[8];
    knak=parameters[9];
    knaca=parameters[10];
    Vmaxup=parameters[11];
    GpCa=parameters[12];
    real arel=parameters[13];
    real crel=parameters[14];
    real Vleak=parameters[15];

    real IKr;
    real IKs;
    real IK1;
    real Ito;
    real INa;
    real IbNa;
    real ICaL;
    real IbCa;
    real INaCa;
    real IpCa;
    real IpK;
    real INaK;
    real Irel;
    real Ileak;


    real dNai;
    real dKi;
    real dCai;
    real dCaSR;

    real A;
//    real BufferFactorc;
//    real BufferFactorsr;
    real SERCA;
    real Caisquare;
    real CaSRsquare;
    real CaCurrent;
    real CaSRCurrent;


    real fcaold;
    real gold;
    real Ek;
    real Ena;
    real Eks;
    real Eca;
    real CaCSQN;
    real bjsr;
    real cjsr;
    real CaBuf;
    real bc;
    real cc;
    real Ak1;
    real Bk1;
    real rec_iK1;
    real rec_ipK;
    real rec_iNaK;
    real AM;
    real BM;
    real AH_1;
    real BH_1;
    real AH_2;
    real BH_2;
    real AJ_1;
    real BJ_1;
    real AJ_2;
    real BJ_2;
    real M_INF;
    real H_INF;
    real J_INF;
    real TAU_M;
    real TAU_H;
    real TAU_J;
    real axr1;
    real bxr1;
    real axr2;
    real bxr2;
    real Xr1_INF;
    real Xr2_INF;
    real TAU_Xr1;
    real TAU_Xr2;
    real Axs;
    real Bxs;
    real Xs_INF;
    real TAU_Xs;
    real R_INF;
    real TAU_R;
    real S_INF;
    real TAU_S;
    real Ad;
    real Bd;
    real Cd;
    real TAU_D;
    real D_INF;
    real TAU_F;
    real F_INF;
    real FCa_INF;
    real G_INF;

    real inverseVcF2=1/(2*Vc*F);
    real inverseVcF=1./(Vc*F);
    real Kupsquare=Kup*Kup;
//    real BufcKbufc=Bufc*Kbufc;
//    real Kbufcsquare=Kbufc*Kbufc;
//    real Kbufc2=2*Kbufc;
//    real BufsrKbufsr=Bufsr*Kbufsr;
//    const real Kbufsrsquare=Kbufsr*Kbufsr;
//    const real Kbufsr2=2*Kbufsr;
    const real exptaufca=exp(-dt/taufca);
    const real exptaug=exp(-dt/taug);

    real sItot;

    //Needed to compute currents
    Ek=RTONF*(log((Ko/Ki)));
    Ena=RTONF*(log((Nao/Nai)));
    Eks=RTONF*(log((Ko+pKNa*Nao)/(Ki+pKNa*Nai)));
    Eca=0.5*RTONF*(log((Cao/Cai)));
    Ak1=0.1/(1.+exp(0.06*(svolt-Ek-200)));
    Bk1=(3.*exp(0.0002*(svolt-Ek+100))+
         exp(0.1*(svolt-Ek-10)))/(1.+exp(-0.5*(svolt-Ek)));
    rec_iK1=Ak1/(Ak1+Bk1);
    rec_iNaK=(1./(1.+0.1245*exp(-0.1*svolt*F/(R*T))+0.0353*exp(-svolt*F/(R*T))));
    rec_ipK=1./(1.+exp((25-svolt)/5.98));


    //Compute currents
    INa=GNa*sm*sm*sm*sh*sj*(svolt-Ena);
    ICaL=GCaL*sd*sf*sfca*4*svolt*(F*F/(R*T))*
         (exp(2*svolt*F/(R*T))*Cai-0.341*Cao)/(exp(2*svolt*F/(R*T))-1.);
    Ito=Gto*sr*ss*(svolt-Ek);
    IKr=Gkr*sqrt(Ko/5.4)*sxr1*sxr2*(svolt-Ek);
    IKs=Gks*sxs*sxs*(svolt-Eks);
    IK1=GK1*rec_iK1*(svolt-Ek);
    INaCa=knaca*(1./(KmNai*KmNai*KmNai+Nao*Nao*Nao))*(1./(KmCa+Cao))*
          (1./(1+ksat*exp((n-1)*svolt*F/(R*T))))*
          (exp(n*svolt*F/(R*T))*Nai*Nai*Nai*Cao-
           exp((n-1)*svolt*F/(R*T))*Nao*Nao*Nao*Cai*2.5);
    INaK=knak*(Ko/(Ko+KmK))*(Nai/(Nai+KmNa))*rec_iNaK;
    IpCa=GpCa*Cai/(KpCa+Cai);
    IpK=GpK*rec_ipK*(svolt-Ek);
    IbNa=GbNa*(svolt-Ena);
    IbCa=GbCa*(svolt-Eca);


    //Determine total current
    (sItot) = IKr    +
              IKs   +
              IK1   +
              Ito   +
              INa   +
              IbNa  +
              ICaL  +
              IbCa  +
              INaK  +
              INaCa +
              IpCa  +
              IpK   +
              stim_current;


    //update concentrations
    Caisquare=Cai*Cai;
    CaSRsquare=CaSR*CaSR;
    CaCurrent=-(ICaL+IbCa+IpCa-2.0f*INaCa)*inverseVcF2*CAPACITANCE;
    A=arel*CaSRsquare/(0.0625f+CaSRsquare)+crel;
    Irel=A*sd*sg;
    Ileak=Vleak*(CaSR-Cai);
    SERCA=Vmaxup/(1.f+(Kupsquare/Caisquare));
    CaSRCurrent=SERCA-Irel-Ileak;
    CaCSQN=Bufsr*CaSR/(CaSR+Kbufsr);
    dCaSR=dt*(Vc/Vsr)*CaSRCurrent;
    bjsr=Bufsr-CaCSQN-dCaSR-CaSR+Kbufsr;
    cjsr=Kbufsr*(CaCSQN+dCaSR+CaSR);
    CaSR=(sqrt(bjsr*bjsr+4.*cjsr)-bjsr)/2.;
    CaBuf=Bufc*Cai/(Cai+Kbufc);
    dCai=dt*(CaCurrent-CaSRCurrent);
    bc=Bufc-CaBuf-dCai-Cai+Kbufc;
    cc=Kbufc*(CaBuf+dCai+Cai);
    Cai=(sqrt(bc*bc+4*cc)-bc)/2;



    dNai=-(INa+IbNa+3*INaK+3*INaCa)*inverseVcF*CAPACITANCE;
    Nai+=dt*dNai;

    dKi=-(stim_current+IK1+Ito+IKr+IKs-2*INaK+IpK)*inverseVcF*CAPACITANCE;
    Ki+=dt*dKi;

    //compute steady state values and time constants
    AM=1./(1.+exp((-60.-svolt)/5.));
    BM=0.1/(1.+exp((svolt+35.)/5.))+0.10/(1.+exp((svolt-50.)/200.));
    TAU_M=AM*BM;
    M_INF=1./((1.+exp((-56.86-svolt)/9.03))*(1.+exp((-56.86-svolt)/9.03)));
    if (svolt>=-40.)
    {
        AH_1=0.;
        BH_1=(0.77/(0.13*(1.+exp(-(svolt+10.66)/11.1))));
        TAU_H= 1.0/(AH_1+BH_1);
    }
    else
    {
        AH_2=(0.057*exp(-(svolt+80.)/6.8));
        BH_2=(2.7*exp(0.079*svolt)+(3.1e5)*exp(0.3485*svolt));
        TAU_H=1.0/(AH_2+BH_2);
    }
    H_INF=1./((1.+exp((svolt+71.55)/7.43))*(1.+exp((svolt+71.55)/7.43)));
    if(svolt>=-40.)
    {
        AJ_1=0.;
        BJ_1=(0.6*exp((0.057)*svolt)/(1.+exp(-0.1*(svolt+32.))));
        TAU_J= 1.0/(AJ_1+BJ_1);
    }
    else
    {
        AJ_2=(((-2.5428e4)*exp(0.2444*svolt)-(6.948e-6)*
                                             exp(-0.04391*svolt))*(svolt+37.78)/
              (1.+exp(0.311*(svolt+79.23))));
        BJ_2=(0.02424*exp(-0.01052*svolt)/(1.+exp(-0.1378*(svolt+40.14))));
        TAU_J= 1.0/(AJ_2+BJ_2);
    }
    J_INF=H_INF;

    Xr1_INF=1./(1.+exp((-26.-svolt)/7.));
    axr1=450./(1.+exp((-45.-svolt)/10.));
    bxr1=6./(1.+exp((svolt-(-30.))/11.5));
    TAU_Xr1=axr1*bxr1;
    Xr2_INF=1./(1.+exp((svolt-(-88.))/24.));
    axr2=3./(1.+exp((-60.-svolt)/20.));
    bxr2=1.12/(1.+exp((svolt-60.)/20.));
    TAU_Xr2=axr2*bxr2;

    Xs_INF=1./(1.+exp((-5.-svolt)/14.));
    Axs=1100./(sqrt(1.+exp((-10.-svolt)/6)));
    Bxs=1./(1.+exp((svolt-60.)/20.));
    TAU_Xs=Axs*Bxs;

    R_INF=1./(1.+exp((20-svolt)/6.));
    S_INF=1./(1.+exp((svolt+20)/5.));
    TAU_R=9.5*exp(-(svolt+40.)*(svolt+40.)/1800.)+0.8;
    TAU_S=85.*exp(-(svolt+45.)*(svolt+45.)/320.)+5./(1.+exp((svolt-20.)/5.))+3.;


    D_INF=1./(1.+exp((-5-svolt)/7.5));
    Ad=1.4/(1.+exp((-35-svolt)/13))+0.25;
    Bd=1.4/(1.+exp((svolt+5)/5));
    Cd=1./(1.+exp((50-svolt)/20));
    TAU_D=Ad*Bd+Cd;
    F_INF=1./(1.+exp((svolt+20)/7));
    //TAU_F=1125*exp(-(svolt+27)*(svolt+27)/300)+80+165/(1.+exp((25-svolt)/10));
    TAU_F=1125*exp(-(svolt+27)*(svolt+27)/240)+80+165/(1.+exp((25-svolt)/10));      // Updated from CellML


    FCa_INF=(1./(1.+pow((Cai/0.000325),8))+
             0.1/(1.+exp((Cai-0.0005)/0.0001))+
             0.20/(1.+exp((Cai-0.00075)/0.0008))+
             0.23 )/1.46;
    if(Cai<0.00035)
        G_INF=1./(1.+pow((Cai/0.00035),6));
    else
        G_INF=1./(1.+pow((Cai/0.00035),16));

    //Update gates
    rDY_[1]  = M_INF-(M_INF-sm)*exp(-dt/TAU_M);
    rDY_[2]  = H_INF-(H_INF-sh)*exp(-dt/TAU_H);
    rDY_[3]  = J_INF-(J_INF-sj)*exp(-dt/TAU_J);
    rDY_[4]  = Xr1_INF-(Xr1_INF-sxr1)*exp(-dt/TAU_Xr1);
    rDY_[5]  = Xr2_INF-(Xr2_INF-sxr2)*exp(-dt/TAU_Xr2);
    rDY_[6]  = Xs_INF-(Xs_INF-sxs)*exp(-dt/TAU_Xs);
    rDY_[7]  = S_INF-(S_INF-ss)*exp(-dt/TAU_S);
    rDY_[8]  = R_INF-(R_INF-sr)*exp(-dt/TAU_R);
    rDY_[9]  = D_INF-(D_INF-sd)*exp(-dt/TAU_D);
    rDY_[10] = F_INF-(F_INF-sf)*exp(-dt/TAU_F);
    fcaold= sfca;
    sfca = FCa_INF-(FCa_INF-sfca)*exptaufca;
    if(sfca>fcaold && (svolt)>-37.0)
        sfca = fcaold;
    gold = sg;
    sg = G_INF-(G_INF-sg)*exptaug;

    if(sg>gold && (svolt)>-37.0)
        sg=gold;

    //update voltage
    rDY_[0] = svolt + dt*(-sItot);
    rDY_[11] = sfca;
    rDY_[12] = sg;
    rDY_[13] = Cai;
    rDY_[14] = CaSR;
    rDY_[15] = Nai;
    rDY_[16] = Ki;
}
