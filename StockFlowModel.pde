StockFlow model;

void setup() {
  
  size(800, 400);
  background(0);
  int year = 2018;
  float population = 70.0;
  
  model = new StockFlow();
  model.PRICE_EQUILIBRIUM = 20.0;
  model.VACANCY_EQUILIBRIUM = 0.1;
  model.SUPPLY_ELASTICITY_PRICE = 0.9;
  model.PRICE_ELASTICITY_SUPPLY = 0.3;
  model.PRICE_ELASTICITY_DEMAND = 0.4;
  model.DEMAND_LAG = 1;
  model.SUPPLY_LAG = 2;
  
  model.initialize(year, population, 25.0, 20.0, 18.5);
  
  for (int i=0; i<20; i++) {
    year += 1;
    population *= 1.01;
    model.timeStep(year, population);
  }
  println(model.toString());
  
  // Print to Table
  //
  String row[];
  for (int i=0; i<model.numRows; i++) {
    row = new String[7];
    row[0] = model.roundFloat(model.time.get(i), 1);
    row[1] = model.roundFloat(model.driver.get(i), 1);
    row[2] = model.roundFloat(model.price.get(i), 1);
    row[3] = model.roundFloat(model.demand.get(i), 1);
    row[4] = model.roundFloat(model.production.get(i), 1);
    row[5] = model.roundFloat(model.supply.get(i), 1);
    row[6] = model.roundFloat(100*model.vacancy.get(i), 1);
    
    for (int j=0; j<7; j++) {
      text(row[j], 5 + j*width/row.length, 15 + i*height/model.numRows);
    }
  }
}

//void draw() {
  
//}

class StockFlow {
  
  /*  This model presumes the following cyclical behaviors:
   *  
   *  1. New Supply is added to stock is produced when past price is above replacement cost
   *  2. Demand for supply in stock is a function of (a) past independent Demand driver and (b) the past price of the asset
   *  3. Price of Asset is determined by the overall Vacancy rate of Supply in Stock   
   *  4. Repeat
   *
   *  Due to the length of time it takes to procure from the supply or manufacture more supply, lags may be present.
   */
   
  // Long-run equilibrium Price ("production cost price")
  float PRICE_EQUILIBRIUM;
  
  // Long-run Ideal Supply Vacancy
  float VACANCY_EQUILIBRIUM;
  
  // 1. Price elasticity of Supply (such as: 0.3).
  float PRICE_ELASTICITY_SUPPLY;
  
  // 2. Price elasticity of Demand (such as: 0.3).
  float PRICE_ELASTICITY_DEMAND;
  
  // 3. Supply elasticity of Price (such as: 0.3).
  float SUPPLY_ELASTICITY_PRICE;
  
  // Demand temporal lag (i.e. time steps to move & occupy)
  int DEMAND_LAG;
  
  // Supply temporal lag (i.e. time steps to build)
  int SUPPLY_LAG;
  
  // Each Array List represents a column of information, 
  // while each element in the list represents a time step in the simulation
  ArrayList<Integer> time;
  ArrayList<Float> driver, price, production, supply, demand, vacancy;
  
  float DEMAND_INTERSECT, DRIVER_SCALER;
  
  int numRows;
  
  StockFlow() {
    // The following constants MUST be finalized before running initialize()
    PRICE_EQUILIBRIUM = 1.0;
    VACANCY_EQUILIBRIUM = 0.1;
    SUPPLY_ELASTICITY_PRICE = 0.3;
    PRICE_ELASTICITY_SUPPLY = 0.3;
    PRICE_ELASTICITY_DEMAND = 0.3;
    DEMAND_LAG = 1;
    SUPPLY_LAG = 3;
    
    numRows = 0;
  }
  
  StockFlow(float p_e, float v_e, float s_e_p, float p_e_s, float p_e_d, int d_l, int s_l) {
    
    super();
    
    PRICE_EQUILIBRIUM = p_e;
    VACANCY_EQUILIBRIUM = v_e;
    SUPPLY_ELASTICITY_PRICE = s_e_p;
    PRICE_ELASTICITY_SUPPLY = p_e_s;
    PRICE_ELASTICITY_DEMAND = p_e_d;
    DEMAND_LAG = d_l;
    SUPPLY_LAG = s_l;
  }
  
  void initialize(int time_0, float driver_0, float price_0, float supply_0, float demand_0) {
    
    // Initialize ArrayLists
    time = new ArrayList<Integer>();
    driver = new ArrayList<Float>();
    price = new ArrayList<Float>();
    production = new ArrayList<Float>();
    supply = new ArrayList<Float>();
    demand = new ArrayList<Float>();
    vacancy = new ArrayList<Float>();
    
    // Initialize Constants
    DRIVER_SCALER = supply_0 / driver_0;
    DEMAND_INTERSECT = demand_0 - DRIVER_SCALER*driver_0 + PRICE_ELASTICITY_DEMAND*price_0;
    
    // Calculate other initial values
    float production_0 = produce(price_0);
    float vacancy_0 = 1.0 - demand_0 / supply_0;
    
    // Initialize First Row
    time.add(time_0);
    driver.add(driver_0);
    price.add(price_0);
    production.add(production_0);
    supply.add(supply_0);
    demand.add(demand_0);
    vacancy.add(vacancy_0);
    
    numRows = 1;
  }
  
  void timeStep(int time_n, float driver_n) {
    
    // Current row's final parameters to establish
    float price_n, production_n, supply_n, demand_n, vacancy_n;
    
    // Intermediate paramters for calculation
    //
    float price_last, supply_last, price_sLag, price_dLag, driver_dLag;
    
    // Prevents Index -1 error
    int lastIndex = max(0, numRows - 1);
    int dLagIndex = max(0, numRows - DEMAND_LAG);
    int sLagIndex = max(0, numRows - SUPPLY_LAG);
    
    price_last = price.get(lastIndex);
    supply_last = supply.get(lastIndex);
    price_sLag = price.get(sLagIndex);
    price_dLag = price.get(dLagIndex);
    driver_dLag = driver.get(dLagIndex);
    
    // 1. Calculate new Production and Supply
    production_n = produce(price_sLag);
    supply_n = supply_last + production_n;
    
    // 2. Calculate new Demand
    demand_n = demand(price_dLag, driver_dLag);
    vacancy_n = 1.0 - demand_n / supply_n;
    
    // 3. Calculate new Price
    price_n = price(price_last, vacancy_n);
    
    // Add Row of Data
    time.add(time_n);
    driver.add(driver_n);
    price.add(price_n);
    production.add(production_n);
    supply.add(supply_n);
    demand.add(demand_n);
    vacancy.add(vacancy_n);
    
    numRows++;
  }
  
  float produce(float price_n) {
    // production is never less than 0
    // producers decide to build when market price of assets is above equilibrium
    println(price_n, PRICE_EQUILIBRIUM, PRICE_ELASTICITY_SUPPLY * max(0, price_n - PRICE_EQUILIBRIUM));
    return PRICE_ELASTICITY_SUPPLY * max(0, price_n - PRICE_EQUILIBRIUM);
  }
  
  float price(float price_last, float vacancy_rate) {
    // Supply owners increase or decrease price when vacancy rate is above or below vacancy rate, respectively
    return price_last - price_last * SUPPLY_ELASTICITY_PRICE * ( vacancy_rate - VACANCY_EQUILIBRIUM );
  }
  
  float demand(float price_n, float driver_n) {
    
    // Portion of Demand driven by external driver
    float demand_from_external = DRIVER_SCALER * driver_n;
    // Portion of Demand driven by price
    float demand_from_price = - PRICE_ELASTICITY_DEMAND * price_n;
    
    return DEMAND_INTERSECT + demand_from_external + demand_from_price;
  }
  
  @Override
  public String toString() {
    String name = "Time, Driver, Price, Demand, Production, Supply, Vacancy\n";
    for (int i=0; i<numRows; i++) {
      name += roundFloat(time.get(i)        , 1) + ", " + 
              roundFloat(driver.get(i)      , 1) + ", " + 
              roundFloat(price.get(i)       , 1) + ", " + 
              roundFloat(demand.get(i)      , 1) + ", " + 
              roundFloat(production.get(i)  , 1) + ", " + 
              roundFloat(supply.get(i)      , 1) + ", " + 
              roundFloat(100*vacancy.get(i) , 1) + "%\n";
    }
    return name;
  }
  
  String roundFloat(float number, int numDecimals) {
    float power = int(pow(10, numDecimals));
    String round = "";
    return round + int(power * number) / power;
  }
}
