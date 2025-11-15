const PLAN_TOKENS = {
  free: 50,
  plus_monthly: 1000,
  plus_annual: 12000,
  pro_monthly: 3000,
  pro_annual: 36000,
};

const hasPlanTokenConfig = (plan) => Object.prototype.hasOwnProperty.call(PLAN_TOKENS, plan);

const getTokensForPlan = (plan) => {
  if (!plan) {
    return 0;
  }
  return PLAN_TOKENS[plan] ?? 0;
};

module.exports = {
  PLAN_TOKENS,
  getTokensForPlan,
  hasPlanTokenConfig,
};
