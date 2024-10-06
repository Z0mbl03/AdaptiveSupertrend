double srcs[];


// identify direction bullish or bearish (1 | -1)
int dir(const double upper, const double lower) {
    int dir = 0;
    if (lower > 0 && upper <= 0) {
        dir = 1;
    } else if (upper > 0 && lower <= 0) {
        dir = -1;
    }

    return(dir);
}


// create entry base
void objEntry(const int action, const datetime time, const double price) {
    static int count = 0;
    string name;
    ENUM_OBJECT type;
    color colr;
    ENUM_ARROW_ANCHOR anchor;

    // action 1 for buy and -1 for sell
    if (action == 0) {return;}

    if (action == 1) {
        name = "Buy"+IntegerToString(count);
        // colr = clrBlue;
        colr = clrLawnGreen;
        type = OBJ_ARROW_UP;
        anchor = ANCHOR_TOP;
    } else {
        name = "Sell"+IntegerToString(count);
        // colr = clrMagenta;
        colr = clrRed;
        type = OBJ_ARROW_DOWN;
        anchor = ANCHOR_BOTTOM;
    }

    bool obj = ObjectCreate(0, name, type, 0, time, price);
    if (!obj) {
        printf("Faile to create entry object. Error Code : %d", GetLastError());
    }

    ObjectSetInteger(0, name, OBJPROP_COLOR, colr);
    ObjectSetInteger(0, name, OBJPROP_ANCHOR, anchor);
    ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);


    //reset count number
    if (count > 300) {
        count = 0;
    }
    count++;
}

// deleted all object with name Sell* and Buy*
void delObj() {
    bool delBuy = ObjectsDeleteAll(0, "Buy*");
    bool delSell = ObjectsDeleteAll(0, "Sell*");
    if (delBuy > 0 && delSell > 0) {
        printf("Removing all object sell and buy !!");
    } else {
        printf("Failed to remove the object. Error Code : %d", GetLastError());
    }
}

// calculating source
void calcSrc(const int currentBar, const double &open[], const double &close[]) {
    if (currentBar <= 0) {return;}

    ArrayResize(srcs, currentBar+1);
    srcs[currentBar] = (open[currentBar] + close[currentBar]) / 2;
}

// placing arrow according the signal
void entryPoint(const int currentBar, const double &open[], const double &close[], const datetime &time[],
                const double lower, const double upper) {


    calcSrc(currentBar, open, close);
    double price=0;
    int action=0;
    int dir = dir(upper, lower);

    if (dir != 0) {
        double treshold = dir == 1 ? (lower*0.15)/100 : (upper*0.15)/100;

        // if dir 1 place buy arrow, else place sell arrow
        if (dir == 1) {
            if ((srcs[currentBar] - lower) <= treshold) {
                bool buyCond = srcs[currentBar] > srcs[currentBar-1] && srcs[currentBar-1] < srcs[currentBar-2];
                if (buyCond) {
                    action = 1;
                    price = srcs[currentBar];
                }
            }
        } if (dir == -1) {
            if ((upper - srcs[currentBar]) <= treshold) {
                bool sellCond = srcs[currentBar] < srcs[currentBar-1] && srcs[currentBar-1] > srcs[currentBar-2];
                if (sellCond) {
                    action = -1;
                    price = srcs[currentBar];
                }
            }
        }
    }

    objEntry(action, time[currentBar], price);
}
