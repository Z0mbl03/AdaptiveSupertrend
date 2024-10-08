

// .·:'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''':·.
// : :                                                                      : :
// : :      ___        __               __   _                              : :
// : :     /   |  ____/ /____ _ ____   / /_ (_)_   __ ___                   : :
// : :    / /| | / __  // __ `// __ \ / __// /| | / // _ \                  : :
// : :   / ___ |/ /_/ // /_/ // /_/ // /_ / / | |/ //  __/                  : :
// : :  /_/  |_|\__,_/ \__,_// .___/ \__//_/  |___/ \___/                   : :
// : :     _____            /_/             __                          __  : :
// : :    / ___/ __  __ ____   ___   _____ / /_ _____ ___   ____   ____/ /  : :
// : :    \__ \ / / / // __ \ / _ \ / ___// __// ___// _ \ / __ \ / __  /   : :
// : :   ___/ // /_/ // /_/ //  __// /   / /_ / /   /  __// / / // /_/ /    : :
// : :  /____/ \__,_// .___/ \___//_/    \__//_/    \___//_/ /_/ \__,_/     : :
// : :              /_/                                                     : :
// : : Implement by z0mbl03                                                 : :
// '·:......................................................................:·'


#property description "Adaptive Supertrend Indicator in MQL5"
#property description "This implementation of the Adaptive Supertrend indicator was ported to MQL5 by z0mbl03."
#property description "The original code was developed by AlphaAlgo on TradingView."
#property description "Original Source:"
#property link "https://www.tradingview.com/script/CLk71Qgy-Machine-Learning-Adaptive-SuperTrend-AlgoAlpha/"

// Import math library
#include <Math/Stat/Normal.mqh>
#include <EntryLabel.mqh>

// deine property Indicator
#property indicator_chart_window
#property indicator_buffers 4
#property indicator_plots 2

// define property for indicator 1
#property indicator_type1 DRAW_LINE
#property indicator_style1 STYLE_SOLID
#property indicator_width1 2
#property indicator_color1 clrCrimson

// Define property for indicator 2
#property indicator_type2 DRAW_LINE
#property indicator_style2 STYLE_SOLID
#property indicator_width2 2
#property indicator_color2 clrLawnGreen


// User input
input int atrLen = 10;             // length of ATR
input double factors = 3.0;                 // supertrend factors
input int trainingDataPeriod = 100;  // Training data Length for K-Means setting. google it to find what is K-Means
input float highVol = 0.75;         // Initial High volatility Percentile Guess
input float midVol = 0.5;           // Initial Medium volatility Percentile Guess
input float lowVol = 0.25;          // Initial Low volatility Percentile Guess

// Global Variable
int atrHandle;
double atrBuffer[];
double upperLine[], lowerLine[];
double midUp[], midDown[];

// Initialize the mql
int OnInit() {
    atrHandle = iATR(_Symbol, _Period, atrLen);

    SetIndexBuffer(0, upperLine, INDICATOR_DATA);
    SetIndexBuffer(1, lowerLine, INDICATOR_DATA);
    SetIndexBuffer(2, midUp, INDICATOR_DATA);
    SetIndexBuffer(3, midDown, INDICATOR_DATA);
    SetIndexBuffer(4, atrBuffer, INDICATOR_CALCULATIONS);

    PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0);
    PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, 0);
    PlotIndexSetString(0, PLOT_LABEL, "UPPER LINE");
    PlotIndexSetString(1, PLOT_LABEL, "LOWER LINE");

    return(INIT_SUCCEEDED);
}

// Calculate the indicator
int OnCalculate(const int rates_total, const int prev_calculated, const datetime &time[],
                    const double &open[], const double &high[], const double &low[],
                    const double &close[], const long &tick_volume[], const long &volum[],
                    const int &spread[]) {
    // inside loop, get all value of history bar and calculated and fill to the buffer.
    // `prev_calculated` parameter is a value of the previous returning `OnCalculate` function / event handler.
    // at the first executeion `OnCalculate` function, prev_calculated value will bee 0.
    // ex : first execute `OnCalculate` function `prev_calculated` parameter will be 0, then `OnCalculate` function
    // return `rates_total` is 2220, then `prev_calculated` will be 2220

    // copy all atr buffer
    if (CopyBuffer(atrHandle, 0, 0, rates_total, atrBuffer) < 0 ) {
        printf("Failed to copy ATR buffer. Error Code : %d", GetLastError());
        return(0);
    }

    int current = prev_calculated;
    for (; current < rates_total-1; current++) {
        // avoid array out of range
        if (current > rates_total - ((rates_total*10)/100)) {
            // exec function for calculation indicator to add
            Supertrend(current, open, high, close, low, time);
            entryPoint(current, open, close, time, lowerLine[current], upperLine[current]);
        }
    }

    // fill buffer with `rates_total-1
    Supertrend(rates_total-1, open, high, close, low, time);
    entryPoint(rates_total-1, open, close, time, lowerLine[rates_total-1], upperLine[rates_total-1]);
    return(rates_total);
}

// De-initialization
void OnDeinit(const int reason) {
    if (reason >= 0 && reason <= 9) {
        // release the indicator handle.
        IndicatorRelease(atrHandle);

        // free the array buffer.
        ArrayFree(atrBuffer);
        ArrayFree(upperLine);
        ArrayFree(lowerLine);
        ArrayFree(midUp);
        ArrayFree(midDown);

        bool checkClear = ArraySize(atrBuffer) == 0 && ArraySize(upperLine) == 0 && ArraySize(lowerLine) == 0 && ArraySize(midUp) == 0 && ArraySize(midDown) == 0;
        if (checkClear) {
            printf("Clear buffer success !!");
        }

        delObj();
        int delUp = ObjectsDeleteAll(0, "UP*");
        int delDn = ObjectsDeleteAll(0, "DN*");
        if (delUp > 0 && delDn > 0) {
            printf("All object deleted !");
        } else {
            printf("Failed to remove obejct. Error Code : %d", GetLastError());
        }
    }
}

// supertend to plotting in chart
void Supertrend(int currentBar,
    const double &open[], const double &high[],
    const double &close[], const double &low[], const datetime &time[]) {

    // define static variable
    static double prevUpperBand, prevLowerBand;
    static int dir[2];

    double atr = clustering(currentBar, atrBuffer);
    double src = (high[currentBar] + low[currentBar]) / 2;
    double upperBand = src + factors * atr;
    double lowerBand = src - factors * atr;

    double Max = high[currentBar] + ((high[currentBar]*95)/100);
    double Min = low[currentBar] - ((close[currentBar]*95)/100);
    bool checkUpBand = (upperBand > prevUpperBand && close[currentBar-1] < prevUpperBand) && !(upperBand < Min || upperBand > Max);
    bool checkDnBand = (lowerBand < prevLowerBand && close[currentBar-1] > prevLowerBand) && !(lowerBand < Min || lowerBand > Max);
    if (checkUpBand) {
        upperBand = prevUpperBand;
    }

    if (checkDnBand) {
        lowerBand = prevLowerBand;
    }

    // check direction
    if (close[currentBar-1] > prevUpperBand) {
        insertBegin(dir, 1, 2);
    } else if(close[currentBar-1] < prevLowerBand) {
        insertBegin(dir, -1, 2);
    }

    double supertrend = 0;
    // insert value into buffer according direction
    if (dir[0] != 0) {
        if (dir[0] == 1) {
            lowerLine[currentBar] = lowerBand;
            supertrend = lowerBand;
        } else {
            upperLine[currentBar] = upperBand;
            supertrend = upperBand;
        }
    }

    // placing placing flag
    if (dir[0] != dir[1]) {
        trendLabel(currentBar, dir[0], time, supertrend);
        insertBegin(dir, dir[0], 2);
    }

    prevUpperBand = upperBand;
    prevLowerBand = lowerBand;
}

double clustering(int currentBar, double const &volatility[]) {
    // initialize cluster and distance array
    double distance[3], centroids[3];

    // Determine volatility band based on hstorical data
    double upper = max(volatility, currentBar, trainingDataPeriod);
    double lower = min(volatility, currentBar, trainingDataPeriod);

    // Define treshold for High, Medium and Low Volatility
    double high = lower + (upper - lower) * highVol;
    double medium = lower + (upper - lower) * midVol;
    double low = lower + (upper - lower) * lowVol;

    double A[2] = {high, 0};
    double B[2] = {medium, 0};
    double C[2] = {low, 0};

    while (A[0] != A[1] || B[0] != B[1] || C[0] != C[1]) {
        // check is there any data broke
        if (checkData(A[0])) {
            printf("Bad data ! A ; %f", A[0]);
            // A[0] = volatility[currentBar-1];
            break;
        } else if (checkData(B[0])) {
            printf("Bad data ! B : %f", B[0]);
            // B[0] = volatility[currentBar-1];
            break;
        } else if (checkData(C[0])) {
            printf("Bad data ! C : %f",C[0]);
            // C[0] = volatility[currentBar-1];
            break;
        }

        // Initialize High, Medium and Low dynamic array to store volatility for each cluster
        double hv[];
        double mv[];
        double lv[];
        int index = currentBar;
        for (; index > (currentBar - trainingDataPeriod); index--) {
            if (checkData(volatility[index])) {
                printf("Bad data quality");
                continue;
            }

            double a = MathAbs(volatility[index] - A[0]);
            double b = MathAbs(volatility[index] - B[0]);
            double c = MathAbs(volatility[index] - C[0]);

            if (a < b && a < c) {
                // Insert volatility[index] value at the beginning hv array
                insertBegin(hv, volatility[index]);
            }

            if (b < a && b < c) {
                // Insert volatility[index] value at the beginning mv array
                insertBegin(mv, volatility[index]);
            }

            if (c < a && c < b) {
                // Insert volatility[index] value at the beginning array
                insertBegin(lv, volatility[index]);
            }
        }

        // Insert average hv, mv, lv to beginning array of each cluste
        insertBegin(A, MathMean(hv), ArraySize(A));
        insertBegin(B, MathMean(mv), ArraySize(B));
        insertBegin(C, MathMean(lv), ArraySize(C));
    }

    distance[0] = MathAbs(volatility[currentBar] - A[0]);
    distance[1] = MathAbs(volatility[currentBar] - B[0]);
    distance[2] = MathAbs(volatility[currentBar] - C[0]);

    centroids[0] = A[0];
    centroids[1] = B[0];
    centroids[2] = C[0];

    int cluster = ArrayMinimum(distance);
    double atr = centroids[cluster];

    return(atr);
}

void trendLabel(const int currentBar, const int dir, const datetime &time[], double price) {
    // avoid create label if direction is 0
    if (dir == 0) {return;}

    string name;
    ENUM_OBJECT type;
    color colrs;
    ENUM_ARROW_ANCHOR anchor;

    if (dir == 1) {
        price = price - ((price*0.02)/100);
        name = "UP"+IntegerToString(currentBar);
        type = OBJ_ARROW_THUMB_UP;
        colrs = clrLawnGreen;
        anchor = ANCHOR_TOP;
    } else {
        price = price + ((price*0.02)/100);
        name = "DN"+IntegerToString(currentBar);
        type = OBJ_ARROW_THUMB_DOWN;
        colrs = clrRed;
        anchor = ANCHOR_BOTTOM;
    }


    bool obj = ObjectCreate(0, name, type, 0, time[currentBar], price);
    if (!obj) {
        printf("failed to create arrow object. Error Code : %d", GetLastError());
    }

    ObjectSetInteger(0, name, OBJPROP_COLOR, colrs);
    ObjectSetInteger(0, name, OBJPROP_ANCHOR, anchor);
    ObjectSetInteger(0, name, OBJPROP_WIDTH, 3);
}


// 3 overload
// insert double value at the begining array
void insertBegin(double &src[], double values, int size) {
    for (int i = size-1; i > 0; i--) {
        src[i] = src[i-1];
    }
    src[0] = values;
}

// insert value at the beginning to dynamic array
void insertBegin(double &src[], double values) {
    int size = ArraySize(src)+1;
    ArrayResize(src, size);
    for (int i = size-1; i > 0; i--) {
        src[i] = src[i-1];
    }
    src[0] = values;
}

// insert integer value at the beginning array
void insertBegin(int &src[], int values, int size) {
    for (int i = size-1; i > 0; i--) {
        src[i] = src[i-1];
    }
    src[0] = values;
}

// Find max value in array
double max(const double &src[], int start=0, int count=0) {
    double max = src[start];
    if (count == 0 ) {
        count = ArraySize(src);
    }

    if (start == 0) {
        for (; start < count; start++) {
            if (src[start] > max) {
                max = src[start];
            }
        }
    } else {
        int i = start;
        for (; i > start-count; i--) {
            if (src[i] > max) {
                max = src[i];
            }
        }
    }

    return(max);
}

// Find min value in array
double min(const double &src[], int start=0, int count=0) {
    double min = src[start];
    if (count == 0) {
        count = ArraySize(src);
    }
    if (start == 0){
        for (; start < count; start++) {
            if (src[start] < min) {
                min = src[start];
            }
        }
    } else {
        int i = start;
        for (; i > start-count; i--) {
            if (src[i] < min) {
                min = src[i];
            }
        }
    }

    return(min);
}

// check data quality
bool checkData(const double values) {
    int len = StringLen(IntegerToString(values));
    if ((int)values < 0 || StringLen((string)IntegerToString(values)) > len){
        return(true); // true stop calculated and wait for new data
    }
    return(false); // false continue calculated data
}
