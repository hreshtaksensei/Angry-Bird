
#include "subroutines.mqh"

bool long_trade = FALSE;
bool short_trade = FALSE;
bool trade_now = FALSE;
double average_price = 0;
double i_lots = 0;
double i_takeprofit = 0;
double last_buy_price = 0;
double last_sell_price = 0;
double lot_multiplier = 0;
double price_target = 0;
double slip = 3.0;
extern double commission = 0.0055;
extern double exp_base = 1.5;
extern double lots = 0.01;
extern double takeprofit = 0;
extern int macd_fast = 3;
extern int macd_slow = 26;
extern int rsi_max = 85.0;
extern int rsi_min = 40.0;
extern int rsi_period = 12;
int error = 0;
int lotdecimal = 2;
int magic_number = 2222;
int pipstep = 0;
int previous_time = 0;
int time_difference = 0;
int total = 0;
int tp_dist;
string comment = "";
string name = "Ilan1.6";

int init()
{
  Update();
  if (total)
  {
    last_buy_price = FindLastBuyPrice();
    last_sell_price = FindLastSellPrice();
    UpdateAveragePrice();
    UpdateOpenOrders();
  }
  return (0);
}

int deinit() { return (0); }
int start()
{
  if (IsOptimization() || IsTesting())
  {
    if (error < 0)
    {
      while (AccountFreeMargin() > 20)
      {
        error = OrderSend(Symbol(), OP_BUY, 0.1, Ask, slip, 0, 0, 0,
                          magic_number, 0, 0);
        error = OrderSend(Symbol(), OP_SELL, 0.1, Bid, slip, 0, 0, 0,
                          magic_number, 0, 0);
      }
      ExpertRemove();
    } /* Updates data only on a trade signal if optimizing */
    time_difference = TimeCurrent() - Time[0];
    if (time_difference < 30 * 5) return (0);
    if (previous_time == Time[0]) return (0);
  } /* Causes trading to wait a certain amount of time after a new bar opens */
  else
  {
    if (error < 0) return (0);
    /* Updates during visual tester */
    if (IsTesting() && !IsOptimization()) Update();
    Update();
    if (time_difference < 50 * 5) return (0);
    if (previous_time == Time[0]) return (0);
  } /* All the actions that occur when a trade is signaled */
  if (IndicatorSignal() > -1)
  { /* Updates data only on a trade signal if optimizing */
    if (IsOptimization() || IsTesting()) Update();

    i_lots = NormalizeDouble(lots * lot_multiplier, lotdecimal);
    if (total == 0)
    {
      short_trade = FALSE;
      long_trade = FALSE;

      if (IndicatorSignal() == OP_BUY)
      {
        long_trade = TRUE;
        error = OrderSend(Symbol(), OP_BUY, i_lots, Ask, slip, 0, 0, name,
                          magic_number, 0, clrLimeGreen);
      }
      if (IndicatorSignal() == OP_SELL)
      {
        short_trade = TRUE;
        error = OrderSend(Symbol(), OP_SELL, i_lots, Bid, slip, 0, 0, name,
                          magic_number, 0, clrHotPink);
      }
      NewOrdersPlaced();
    }
    else
    {
      if (IndicatorSignal() == OP_SELL)
      {
        if (short_trade && Bid > last_sell_price + pipstep * Point)
        {
          error = OrderSend(Symbol(), OP_SELL, i_lots, Bid, slip, 0, 0, name,
                            magic_number, 0, clrHotPink);
          NewOrdersPlaced();
        }
        if (long_trade && Ask < last_buy_price - pipstep * Point)
        {
          CloseThisSymbolAll();
          error = OrderSend(Symbol(), OP_SELL, i_lots, Bid, slip, 0, 0, name,
                            magic_number, 0, clrHotPink);
          short_trade = TRUE;
          long_trade = FALSE;
          NewOrdersPlaced();
        }
      }
      if (IndicatorSignal() == OP_BUY)
      {
        if (long_trade && Ask < last_buy_price - pipstep * Point)
        {
          error = OrderSend(Symbol(), OP_BUY, i_lots, Ask, slip, 0, 0, name,
                            magic_number, 0, clrLimeGreen);
          NewOrdersPlaced();
        }
        if (short_trade && Bid > last_sell_price + pipstep * Point)
        {
          CloseThisSymbolAll();
          error = OrderSend(Symbol(), OP_BUY, i_lots, Ask, slip, 0, 0, name,
                            magic_number, 0, clrLimeGreen);
          short_trade = FALSE;
          long_trade = TRUE;
          NewOrdersPlaced();
        }
      }
    }
  }
  return (0);
}

void NewOrdersPlaced()
{
  previous_time = Time[0];
  last_buy_price = FindLastBuyPrice();
  last_sell_price = FindLastSellPrice();
  total = CountTrades();
  UpdateAveragePrice();
  UpdateOpenOrders();
}

void Update()
{
  time_difference = TimeCurrent() - Time[0];
  total = CountTrades();
  /* Alerts on error */
  if (error < 0) Alert("Error " + GetLastError());
  if (short_trade)
    tp_dist = (Bid - price_target) / Point;
  else if (long_trade)
    tp_dist = (price_target - Ask) / Point;
  else
    tp_dist = 0;
  i_takeprofit = takeprofit + (Bid * commission) / Point;

  pipstep = i_takeprofit * MathAbs(iMACD(NULL, 0, macd_fast, macd_slow, 9,
                                         PRICE_TYPICAL, MODE_MAIN, 0));
  if (total > 0)
    lot_multiplier = MathPow(exp_base, (tp_dist * total / i_takeprofit));
  else
    lot_multiplier = 1;

  Comment(
          "\nPipstep: " + pipstep +
          "\nLong Trade: " + long_trade +
          "\nTake Profit: " + i_takeprofit +
          "\nTime passed: " + time_difference +
          "\nShort Trade: " + short_trade +
          "\nAverage Price: " + average_price +
          "\nLot Multiplier: " + lot_multiplier +
          "\nTake Profit Distance: " + tp_dist
          );
}

void UpdateAveragePrice()
{
  average_price = 0;
  double count = 0;

  for (int i = 0; i < total; i++)
  {
    error = OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
    if (OrderSymbol() == Symbol() && OrderMagicNumber() == magic_number)
    {
      average_price += OrderOpenPrice() * OrderLots();
      count += OrderLots();
    }
  }

  average_price /= total;
  count /= total;
  average_price = average_price / count;
}

void UpdateOpenOrders()
{
  for (int i = 0; i < total; i++)
  {
    error = OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
    if (OrderSymbol() == Symbol() && OrderMagicNumber() == magic_number)
    {
      if (OrderType() == OP_BUY)
        price_target = average_price + (i_takeprofit * Point);
      if (OrderType() == OP_SELL)
        price_target = average_price - (i_takeprofit * Point);

      error = OrderModify(OrderTicket(), NULL,
                          NormalizeDouble(OrderStopLoss(), Digits),
                          NormalizeDouble(price_target, Digits), 0, Yellow);
    }
  }
}

int IndicatorSignal()
{
  if (iRSI(NULL, 0, rsi_period, PRICE_TYPICAL, 0) > rsi_max) return OP_SELL;
  if (iRSI(NULL, 0, rsi_period, PRICE_TYPICAL, 0) < rsi_min) return OP_BUY;
  return (-1);
}
