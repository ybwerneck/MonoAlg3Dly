// Author: Lucas Berg

#include <iostream>
#include <string>
#include <vector>
#include <map>
#include <fstream>
#include <cstdlib>
#include <cstdio>

#define PRINT_LINE "============================================================================="
#define NUMBER_EQUATIONS 17
#define NUMBER_PARAMETERS 16

using namespace std;

std::map<uint32_t,std::string> dictionary;

class Scenario
{
public:
    std::string name;
    std::vector<double> initial_conditions;
    std::vector<double> parameters;
public:
    Scenario (std::string name, double *sv, double *param)
    {
        this->name = name;
        for (uint32_t i = 0; i < NUMBER_EQUATIONS; i++)
            initial_conditions.push_back(sv[i]);
        for (uint32_t i = 0; i < NUMBER_PARAMETERS; i++)
            parameters.push_back(param[i]);
    }
    void print ()
    {
        printf("%s\n",PRINT_LINE);
        printf("Name: %s\n\n",this->name.c_str());
        printf("Initial conditions:\n");
        for (uint32_t i = 0; i < NUMBER_EQUATIONS; i++)
            printf("%s = %g\n",dictionary[i].c_str(),initial_conditions[i]);
        printf("\n");
        printf("Parameters:\n");
        for (uint32_t i = 0; i < NUMBER_PARAMETERS; i++)
            printf("%s = %g\n",dictionary[NUMBER_EQUATIONS+i].c_str(),parameters[i]);
        printf("%s\n",PRINT_LINE);
    }
};


void initialize_dictionary (std::map<uint32_t,std::string> &dictionary)
{
    dictionary[0] = "V";
    dictionary[1] = "M";
    dictionary[2] = "H";
    dictionary[3] = "J";
    dictionary[4] = "Xr1";
    dictionary[5] = "Xr2";
    dictionary[6] = "Xs";
    dictionary[7] = "S";
    dictionary[8] = "R";
    dictionary[9] = "D";
    dictionary[10] = "F";
    dictionary[11] = "FCa";
    dictionary[12] = "G";
    dictionary[13] = "Cai";
    dictionary[14] = "CaSR";
    dictionary[15] = "Nai";
    dictionary[16] = "Ki";

    dictionary[17] = "GNa";
    dictionary[18] = "GbNa";
    dictionary[19] = "GCaL";
    dictionary[20] = "GbCa";
    dictionary[21] = "Gto";
    dictionary[22] = "Gkr";
    dictionary[23] = "Gks";
    dictionary[24] = "GK1";
    dictionary[25] = "GpK";
    dictionary[26] = "knak";
    dictionary[27] = "knaca";
    dictionary[28] = "Vmaxup";
    dictionary[29] = "GpCa";
    dictionary[30] = "arel";
    dictionary[31] = "crel";
    dictionary[32] = "Vleak";
}

int main (int argc, char *argv[])
{
    initialize_dictionary(dictionary);

    // Original TenTusscher
    double sv_sc0[]={-86.4172552153702,0.00133233093318418,0.775980725003160,0.775871451583533,0.000178484465968596,0.483518904573916,0.00297208335439809,0.999998297825169,1.98274727808946e-08,1.92952362196655e-05,0.999768268008847,1.00667048889468,0.999984854519288,5.50424977684767e-05,0.352485262813812,10.8673127043200,138.860197273148};
    double param_sc0[]={14.838,0.00029,0.000175,0.000592,0.294,0.096,0.062,5.405,0.0146,1.362,1000,0.000425,0.825,0.016464,0.008232,0.00008};
    
    // Scenario 1
    double sv_sc1[]={-86.7787928226268,0.00123339508649700,0.784831144233936,0.784673023102172,0.000169405106163081,0.487281523786458,0.00289654265697758,0.999998418745548,1.86681673058670e-08,1.83872100639159e-05,0.999777546403090,1.00731261455043,0.999997755681027,4.00467125306598e-05,0.953040239833913,9.39175391367938,139.965667493392};
    double param_sc1 []={13.7730247891532,0.000208550376791424,0.000166345602997405,0.000314427207496467,0.272150547490643,0.206045798160674,0.134878222351137,2.91860118931279,0.0222099400341836,2.12194476134155,1099.53480175178,0.000604923870766662,0.118384383617544,0.0193733747777405,0.00390066599158743,2.21704721596155e-05};

    // Scenario 2
    double sv_sc2[]={-86.6902768323595,0.00125688376225555,0.782690257165761,0.782547892596001,0.000171750048746746,0.486360170563085,0.00291485827479809,0.999998387931464,1.89456679295569e-08,1.86054940017131e-05,0.999770742626069,1.00724037170339,0.999997113579370,4.17567836043613e-05,0.472458747863693,10.1478189383772,139.471917130272};
    double param_sc2 []={14.2265776064284,0.000280045021984329,0.000123702304592752,0.000251556675811958,0.224623739779267,0.145045477736859,0.132102752427711,4.42712254301024,0.0156948843567210,1.61691730440283,1100,0.000520888772463349,0.258756467150201,0.0191544497099730,0.00137164828832637,4.52996729499983e-05};

    // Scenario 2.1
    double sv_sc2_1[]={-86.7787928226268,0.00123339508649700,0.784831144233936,0.784673023102172,0.000169405106163081,0.487281523786458,0.00289654265697758,0.999998418745548,1.86681673058670e-08,1.83872100639159e-05,0.999777546403090,1.00731261455043,0.999997755681027,4.00467125306598e-05,0.953040239833913,9.39175391367938,139.965667493392};
    double param_sc2_1 []={13.7730247891532,0.000208550376791424,0.000166345602997405,0.000314427207496467,0.272150547490643,0.206045798160674,0.134878222351137,2.91860118931279,0.0222099400341836,2.12194476134155,1099.53480175178,0.000604923870766662,0.118384383617544,0.0193733747777405,0.00390066599158743,2.21704721596155e-05};
    
    // Scenario 2.2
    double sv_sc2_2[]={-86.6775309540028,0.00126031074107193,0.782379594133090,0.782216749001106,0.000172068343086772,0.486227463562957,0.00291750746806204,0.999998383839518,1.89860165324306e-08,1.86371442934849e-05,0.999771183306077,1.00730952275387,0.999997729764813,4.01181567168462e-05,0.661435383223664,9.89216406636310,139.601234209998};
    double param_sc2_2 []={13.9645635317638,0.000234559273515713,0.000158508496150117,0.000387718953473422,0.271550011299244,0.171313643894679,0.148132634408518,3.52429749186627,0.0163232963007063,1.80625170161156,1099.99984094905,0.000508428591582056,0.426315288126368,0.0193610246251599,0.00342305438925442,2.79133840240607e-05};

    // Scenario 3
    double sv_sc3[]={-86.7596599603487,0.00123838857632763,0.784369818846026,0.784223148947282,0.000169972136689011,0.487082365294413,0.00290049182352458,0.999998410215409,1.87279005544269e-08,1.84341746908718e-05,0.999781004659642,1.00771223118124,0.999999564103621,3.04673432492567e-05,0.993358298469861,10.1763606222150,139.168522102236};
    double param_sc3 []={14.6970262149558,2.32527331724419e-05,0.000121747898718481,0.000276971880166082,0.210038991991875,0.120908114803453,0.200498466936257,5.12988959137240,0.0151231713364490,1.26415205898593,1083.02600285230,0.000542147164379904,0.160470068504854,0.0146070055973378,0.00183114105726186,1.00487709573505e-05};

    // Scenario 3.1
    double sv_sc3_1[]={-86.6902768323595,0.00125688376225555,0.782690257165761,0.782547892596001,0.000171750048746746,0.486360170563085,0.00291485827479809,0.999998387931464,1.89456679295569e-08,1.86054940017131e-05,0.999770742626069,1.00724037170339,0.999997113579370,4.17567836043613e-05,0.472458747863693,10.1478189383772,139.471917130272};
    double param_sc3_1 []={14.2265776064284,0.000280045021984329,0.000123702304592752,0.000251556675811958,0.224623739779267,0.145045477736859,0.132102752427711,4.42712254301024,0.0156948843567210,1.61691730440283,1100,0.000520888772463349,0.258756467150201,0.0191544497099730,0.00137164828832637,4.52996729499983e-05};

    // Scenario 3.2
    double sv_sc3_2[]={-86.5236591284772,0.00130241284471985,0.778613483022969,0.778472769811598,0.000175875277625194,0.484626058693879,0.00294965177778795,0.999998333317616,1.94791112184908e-08,1.90234417053386e-05,0.999779558473224,1.00713872511970,0.999995965310622,4.41551215458988e-05,0.567040008888733,10.2464162625462,139.303734550690};
    double param_sc3_2 []={14.2751110459407,0.000197490405913840,0.000138093676576538,0.000459611951400222,0.248312214169369,0.146550920650185,0.141336894566835,4.51002424199619,0.0147942147525980,1.60874334855823,1098.91591518736,0.000497071049372500,0.357179450926053,0.0190817376935230,0.00515881032161095,3.63348608264117e-05};
 
    // Scenario 3.3
    double sv_sc3_3[]={-86.6404915792850,0.00127032163211322,0.781479753157976,0.781360816517016,0.000172969600594225,0.485842045427499,0.00292520813217015,0.999998371823369,1.91034113695031e-08,1.87293970187045e-05,0.999771221267447,1.00691525856031,0.999992103392003,4.93846276389813e-05,0.695256716079829,9.83880114557068,139.633017313049};
    double param_sc3_3 []={14.4701107547473,0.000162061905578968,0.000188488521383406,0.000572929459830166,0.335244898151308,0.119541023695594,0.248924317567785,5.19603253018384,0.0221271053316735,2.03169412747953,1099.72574265209,0.000483122952800270,0.478907546954075,0.0199668557152203,0.00562797831559110,3.64128969863145e-05};

    Scenario *sc0 = new Scenario("Scenario 0 - (Original)",sv_sc0,param_sc0);
    sc0->print();

    Scenario *sc1 = new Scenario("Scenario 1 - (AP + max:dvdt)",sv_sc1,param_sc1);
    sc1->print();

    Scenario *sc2 = new Scenario("Scenario 2 - (AP + max:dvdt + Rc)",sv_sc2,param_sc2);
    sc2->print();

    Scenario *sc2_1 = new Scenario("Scenario 2.1 - (AP + max:dvdt + Rc)",sv_sc2_1,param_sc2_1);
    sc2_1->print();

    Scenario *sc2_2 = new Scenario("Scenario 2.2 - (AP + max:dvdt + Rc)",sv_sc2_2,param_sc2_2);
    sc2_2->print();

    Scenario *sc3 = new Scenario("Scenario 3 - (AP + max:dvdt + Rd)",sv_sc3,param_sc3);
    sc3->print();

    Scenario *sc3_1 = new Scenario("Scenario 3.1 - (AP + max:dvdt + Rd)",sv_sc3_1,param_sc3_1);
    sc3_1->print();

    Scenario *sc3_2 = new Scenario("Scenario 3.2 - (AP + max:dvdt + Rd)",sv_sc3_2,param_sc3_2);
    sc3_2->print();

    Scenario *sc3_3 = new Scenario("Scenario 3.3 - (AP + max:dvdt + Rd)",sv_sc3_3,param_sc3_3);
    sc3_3->print();

    delete sc0;
    delete sc1;
    delete sc2;
    delete sc2_1;
    delete sc2_2;
    delete sc3;
    delete sc3_1;
    delete sc3_2;
    delete sc3_3;

    return 0;
}
