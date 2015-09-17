bool flag = FALSE;
bool LongTrade = FALSE;
bool NewOrdersPlaced = FALSE;
bool ShortTrade = FALSE;
bool TradeNow = FALSE;
bool UseEquityStop = FALSE;
bool UseTimeOut = FALSE;
bool UseTrailingStop = FALSE;
double AccntEquityHighAmt = 0;
double AveragePrice = 0;
double BuyLimit = 0;
double BuyTarget = 0;
double Drop = 500;
double iLots = 0;
double LastBuyPrice = 0;
double LastSellPrice = 0;
double MaxTradeOpenHours = 48.0;
double PrevEquity = 0;
double PriceTarget = 0;
double RsiMaximum = 70.0;
double RsiMinimum = 30.0;
double SellLimit = 0;
double SellTarget = 0;
double slip = 3.0;
double Spread = 0;
double StartEquity = 0;
double Stoploss = 500.0;
double Stopper = 0.0;
double TotalEquityRisk = 20.0;
double TrailStart = 10.0;
extern bool DynamicPips = TRUE;
extern double LotExponent = 2;
extern double Lots = 0.01;
extern double TakeProfit = 20.0;
extern double TrailStop = 10.0;
extern int DefaultPips = 12;
extern int DEL = 3;
extern int Glubina = 24;
extern int MaxTrades = 10;
int cnt = 0;
int expiration = 0;
int lotdecimal = 2;
int MagicNumber = 2222;
int NumOfTrades = 0;
int PipStep = 0;
int ticket = 0;
int timeprev = 0;
int total = 0;
string EAName = "Ilan1.6";

/* Init */
int init() {
  Spread = MarketInfo(Symbol(), MODE_SPREAD) * Point;
  return (0);
}

/* Deinit */
int deinit() { return (0); }

/* Start Loop */
int start() {
  /* Dynamic Pips */
  if (DynamicPips) {
    /* calculate highest and lowest price from last bar to 24 bars ago */
    double hival = High[iHighest(NULL, 0, MODE_HIGH, Glubina, 1)];
    double loval = Low[iLowest(NULL, 0, MODE_LOW, Glubina, 1)];
    /* calculate pips for spread between orders */
    PipStep = NormalizeDouble((hival - loval) / DEL / Point, 0);
    /* if dynamic pips fail, assign pips extreme value */
    if (PipStep < DefaultPips / DEL) {
      PipStep = NormalizeDouble(DefaultPips / DEL, 0);
    }
    if (PipStep > DefaultPips * DEL) {
      PipStep = NormalizeDouble(DefaultPips * DEL, 0);

    }
  } else {
    PipStep = DefaultPips;
  }

  /* Trailing Stop */
  if (UseTrailingStop) {
    TrailingAlls(TrailStart, TrailStop, AveragePrice);
  }

  /* Time Out */
  if ((iCCI(NULL, 15, 55, 0, 0) > Drop && ShortTrade) ||
      (iCCI(NULL, 15, 55, 0, 0) < (-Drop) && LongTrade)) {
    CloseThisSymbolAll();
    Print("Closed All due to TimeOut");
  }

  /* ??? */
  if (timeprev == Time[0]) {return (0); }
  timeprev = Time[0];

  /* Equitiy Stop */
  double CurrentPairProfit = CalculateProfit();
  if (UseEquityStop) {
    if (CurrentPairProfit < 0.0 &&
        MathAbs(CurrentPairProfit) >
            TotalEquityRisk / 100.0 * AccountEquityHigh()) {
      CloseThisSymbolAll();
      Print("Closed All due to Stop Out");
      NewOrdersPlaced = FALSE;
    }
  }

  /* Trades */
  total = CountTrades();
  if (total == 0) flag = FALSE;
  for (cnt = OrdersTotal() - 1; cnt >= 0; cnt--) {
    if (!OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES)) {
      check_err();
    };
    if (OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
      continue;
    if (OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber) {
      if (OrderType() == OP_BUY) {
        LongTrade = TRUE;
        ShortTrade = FALSE;
        break;
      }
    }
    if (OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber) {
      if (OrderType() == OP_SELL) {
        LongTrade = FALSE;
        ShortTrade = TRUE;
        break;
      }
    }
  }
  if (total > 0 && total <= MaxTrades) {
    RefreshRates();
    LastBuyPrice = FindLastBuyPrice();
    LastSellPrice = FindLastSellPrice();
    if (LongTrade && LastBuyPrice - Ask >= PipStep * Point) TradeNow = TRUE;
    if (ShortTrade && Bid - LastSellPrice >= PipStep * Point) TradeNow = TRUE;
  }
  if (total < 1) {
    ShortTrade = FALSE;
    LongTrade = FALSE;
    TradeNow = TRUE;
    StartEquity = AccountEquity();
  }
  if (TradeNow) {
    LastBuyPrice = FindLastBuyPrice();
    LastSellPrice = FindLastSellPrice();
    if (ShortTrade) {
      NumOfTrades = total;
      iLots =
          NormalizeDouble(Lots * MathPow(LotExponent, NumOfTrades), lotdecimal);
      RefreshRates();
      ticket = OpenPendingOrder(1, iLots, Bid, slip, Ask, 0, 0,
                                EAName + "-" + NumOfTrades + "-" + PipStep,
                                MagicNumber, 0, HotPink);
      Print(CountTrades());
      LastSellPrice = FindLastSellPrice();
      TradeNow = FALSE;
      NewOrdersPlaced = TRUE;
    } else {
      if (LongTrade) {
        NumOfTrades = total;
        iLots = NormalizeDouble(Lots * MathPow(LotExponent, NumOfTrades),
                                lotdecimal);
        ticket = OpenPendingOrder(0, iLots, Ask, slip, Bid, 0, 0,
                                  EAName + "-" + NumOfTrades + "-" + PipStep,
                                  MagicNumber, 0, Lime);
        LastBuyPrice = FindLastBuyPrice();
        TradeNow = FALSE;
        NewOrdersPlaced = TRUE;
      }
    }
    if (ticket < 0) {
      check_err();
      return (-1);
    }
  }
  if (TradeNow && total < 1) {
    double PrevCl = iClose(Symbol(), 0, 2);
    double CurrCl = iClose(Symbol(), 0, 1);
    SellLimit = Bid;
    BuyLimit = Ask;
    if (!ShortTrade && !LongTrade) {
      NumOfTrades = total;
      iLots =
          NormalizeDouble(Lots * MathPow(LotExponent, NumOfTrades), lotdecimal);
      if (PrevCl > CurrCl) {
        if (iRSI(NULL, PERIOD_H1, 14, PRICE_CLOSE, 1) > RsiMinimum) {
          ticket = OpenPendingOrder(1, iLots, SellLimit, slip, SellLimit, 0, 0,
                                    EAName + "-" + NumOfTrades, MagicNumber, 0,
                                    HotPink);
          LastBuyPrice = FindLastBuyPrice();
          NewOrdersPlaced = TRUE;
        }
      } else {
        if (iRSI(NULL, PERIOD_H1, 14, PRICE_CLOSE, 1) < RsiMaximum) {
          ticket = OpenPendingOrder(0, iLots, BuyLimit, slip, BuyLimit, 0, 0,
                                    EAName + "-" + NumOfTrades, MagicNumber, 0,
                                    Lime);
          LastSellPrice = FindLastSellPrice();
          NewOrdersPlaced = TRUE;
        }
      }
      if (ticket < 0) {
        check_err();
        return (0);
      } else {
        expiration = TimeCurrent() + 60.0 * (60.0 * MaxTradeOpenHours);
      }
      TradeNow = FALSE;
    }
  }
  total = CountTrades();
  AveragePrice = 0;
  double Count = 0;
  for (cnt = OrdersTotal() - 1; cnt >= 0; cnt--) {
    if (!OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES)) {
      check_err();
    }
    if (OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
      continue;
    if (OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber) {
      if (OrderType() == OP_BUY || OrderType() == OP_SELL) {
        AveragePrice += OrderOpenPrice() * OrderLots();
        Count += OrderLots();
      }
    }
  }
  if (total > 0) AveragePrice = NormalizeDouble(AveragePrice / Count, Digits);
  if (NewOrdersPlaced) {
    for (cnt = OrdersTotal() - 1; cnt >= 0; cnt--) {
      if (!OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES)) {
        check_err();
      }
      if (OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
        continue;
      if (OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber) {
        if (OrderType() == OP_BUY) {
          PriceTarget = AveragePrice + TakeProfit * Point;
          BuyTarget = PriceTarget;
          Stopper = AveragePrice - Stoploss * Point;
          flag = TRUE;
        }
      }
      if (OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber) {
        if (OrderType() == OP_SELL) {
          PriceTarget = AveragePrice - TakeProfit * Point;
          SellTarget = PriceTarget;
          Stopper = AveragePrice + Stoploss * Point;
          flag = TRUE;
        }
      }
    }
  }
  if (NewOrdersPlaced) {
    if (flag == TRUE) {
      for (cnt = OrdersTotal() - 1; cnt >= 0; cnt--) {
        if (!OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES)) {
          check_err();
        }
        if (OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
          continue;
        if (OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber) {
          if (!OrderModify(OrderTicket(), NormalizeDouble(AveragePrice, Digits),
                           NormalizeDouble(OrderStopLoss(), Digits),
                           NormalizeDouble(PriceTarget, Digits), 0, Yellow)) {
            check_err();
          }
        }
        NewOrdersPlaced = FALSE;
      }
    }
  }

  /* End of loop */
  return (0);
}

/*Helper Functions*/
int CountTrades() {
  int count = 0;
  for (int trade = OrdersTotal() - 1; trade >= 0; trade--) {
    if (!OrderSelect(trade, SELECT_BY_POS, MODE_TRADES)) {
      check_err();
    }
    if (OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
      continue;
    if (OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber)
      if (OrderType() == OP_SELL || OrderType() == OP_BUY) count++;
  }
  return (count);
}
void CloseThisSymbolAll() {
  for (int trade = OrdersTotal() - 1; trade >= 0; trade--) {
    if (!OrderSelect(trade, SELECT_BY_POS, MODE_TRADES)) {
      check_err();
    }
    if (OrderSymbol() == Symbol()) {
      if (OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber) {
        if (OrderType() == OP_BUY)
          if (!OrderClose(OrderTicket(), OrderLots(), Bid, slip, Blue)) {
            check_err();
          }
        if (OrderType() == OP_SELL)
          if (!OrderClose(OrderTicket(), OrderLots(), Ask, slip, Red)) {
            check_err();
          }
      }
      Sleep(1000);
    }
  }
}
int OpenPendingOrder(int pType, double pLots, double pLevel, int sp, double pr,
                     int sl, int tp, string pComment, int pMagic, int pDatetime,
                     color pColor) {
  int c = 0;
  int NumberOfTries = 100;
  switch (pType) {
    case 2:
      for (c = 0; c < NumberOfTries; c++) {
        ticket = OrderSend(Symbol(), OP_BUYLIMIT, pLots, pLevel, sp,
                           StopLong(pr, sl), TakeLong(pLevel, tp), pComment,
                           pMagic, pDatetime, pColor);
        if (!check_err()) break;
      }
      break;
    case 4:
      for (c = 0; c < NumberOfTries; c++) {
        ticket = OrderSend(Symbol(), OP_BUYSTOP, pLots, pLevel, sp,
                           StopLong(pr, sl), TakeLong(pLevel, tp), pComment,
                           pMagic, pDatetime, pColor);
        if (!check_err()) break;
      }
      break;
    case 0:
      for (c = 0; c < NumberOfTries; c++) {
        RefreshRates();
        ticket =
            OrderSend(Symbol(), OP_BUY, pLots, NormalizeDouble(Ask, Digits), sp,
                      NormalizeDouble(StopLong(Bid, sl), Digits),
                      NormalizeDouble(TakeLong(Ask, tp), Digits), pComment,
                      pMagic, pDatetime, pColor);
        if (!check_err()) break;
      }
      break;
    case 3:
      for (c = 0; c < NumberOfTries; c++) {
        ticket = OrderSend(Symbol(), OP_SELLLIMIT, pLots, pLevel, sp,
                           StopShort(pr, sl), TakeShort(pLevel, tp), pComment,
                           pMagic, pDatetime, pColor);
        if (!check_err()) break;
      }
      break;
    case 5:
      for (c = 0; c < NumberOfTries; c++) {
        ticket = OrderSend(Symbol(), OP_SELLSTOP, pLots, pLevel, sp,
                           StopShort(pr, sl), TakeShort(pLevel, tp), pComment,
                           pMagic, pDatetime, pColor);
        if (!check_err()) break;
      }
      break;
    case 1:
      for (c = 0; c < NumberOfTries; c++) {
        ticket =
            OrderSend(Symbol(), OP_SELL, pLots, NormalizeDouble(Bid, Digits),
                      sp, NormalizeDouble(StopShort(Ask, sl), Digits),
                      NormalizeDouble(TakeShort(Bid, tp), Digits), pComment,
                      pMagic, pDatetime, pColor);
        if (!check_err()) break;
      }
  }
  return (ticket);
}
double StopLong(double price, int stop) {
  if (stop == 0)
    return (0);
  else
    return (price - stop * Point);
}
double StopShort(double price, int stop) {
  if (stop == 0)
    return (0);
  else
    return (price + stop * Point);
}
double TakeLong(double price, int stop) {
  if (stop == 0)
    return (0);
  else
    return (price + stop * Point);
}
double TakeShort(double price, int stop) {
  if (stop == 0)
    return (0);
  else
    return (price - stop * Point);
}
double CalculateProfit() {
  double Profit = 0;
  for (cnt = OrdersTotal() - 1; cnt >= 0; cnt--) {
    if (!OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES)) {
      check_err();
    }
    if (OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
      continue;
    if (OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber)
      if (OrderType() == OP_BUY || OrderType() == OP_SELL)
        Profit += OrderProfit();
  }
  return (Profit);
}
void TrailingAlls(int pType, int stop, double AvgPrice) {
  if (stop != 0) {
    for (int trade = OrdersTotal() - 1; trade >= 0; trade--) {
      if (OrderSelect(trade, SELECT_BY_POS, MODE_TRADES)) {
        if (OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
          continue;
        if (OrderSymbol() == Symbol() || OrderMagicNumber() == MagicNumber) {
          if (OrderType() == OP_BUY) {
            double stoptrade = 0;
            double stopcal = 0;
            int profit = 0;
            profit = NormalizeDouble((Bid - AvgPrice) / Point, 0);
            if (profit < pType) continue;
            stoptrade = OrderStopLoss();
            stopcal = Bid - stop * Point;
            if (stoptrade == 0.0 || (stopcal > stoptrade)) {
              if (!OrderModify(OrderTicket(), AvgPrice, stopcal,
                               OrderTakeProfit(), 0, Aqua)) {
                check_err();
              }
            }
          }
          if (OrderType() == OP_SELL) {
            profit = NormalizeDouble((AvgPrice - Ask) / Point, 0);
            if (profit < pType) continue;
            stoptrade = OrderStopLoss();
            stopcal = Ask + stop * Point;
            if (stoptrade == 0.0 || (stopcal < stoptrade)) {
              if (!OrderModify(OrderTicket(), AvgPrice, stopcal,
                               OrderTakeProfit(), 0, Red)) {
                check_err();
              }
            }
          }
        }
        Sleep(1000);
      }
    }
  }
}
double AccountEquityHigh() {
  if (CountTrades() == 0) AccntEquityHighAmt = AccountEquity();
  if (AccntEquityHighAmt < PrevEquity)
    AccntEquityHighAmt = PrevEquity;
  else
    AccntEquityHighAmt = AccountEquity();
  PrevEquity = AccountEquity();

  return (AccntEquityHighAmt);
}
double FindLastBuyPrice() {
  double oldorderopenprice;
  int oldticketnumber;
  int ticketnumber = 0;
  for (cnt = OrdersTotal() - 1; cnt >= 0; cnt--) {
    if (!OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES)) {
      check_err();
    }
    if (OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
      continue;
    if (OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber &&
        OrderType() == OP_BUY) {
      oldticketnumber = OrderTicket();
      if (oldticketnumber > ticketnumber) {
        oldorderopenprice = OrderOpenPrice();
        ticketnumber = oldticketnumber;
      }
    }
  }
  return (oldorderopenprice);
}
double FindLastSellPrice() {
  double oldorderopenprice;
  int oldticketnumber;
  int ticketnumber = 0;
  for (cnt = OrdersTotal() - 1; cnt >= 0; cnt--) {
    if (!OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES)) {
      check_err();
    }
    if (OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
      continue;
    if (OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber &&
        OrderType() == OP_SELL) {
      oldticketnumber = OrderTicket();
      if (oldticketnumber > ticketnumber) {
        oldorderopenprice = OrderOpenPrice();
        ticketnumber = oldticketnumber;
      }
    }
  }
  return (oldorderopenprice);
}
bool check_err() {
  int err = GetLastError();
  if (err) Print("Error: " + err);
  return (err == 4 /* SERVER_BUSY */ || err == 137 /* BROKER_BUSY */
          || err == 146 /* TRADE_CONTEXT_BUSY */ ||
          err == 136 /* OFF_QUOTES */);
}
