const BASE_URL = import.meta.env.VITE_API_BASE_URL || 'https://impulsepromotions.co.ke/api/airlogix';
import { appConfig } from '$lib/config/appConfig';

// Svelte 5 rune-based store for currency
let currentCurrency = $state(appConfig.defaultCurrency);
// Fixer-style rates relative to EUR.
let rates = $state({ EUR: 1, USD: 1.08, KES: 140.0, TZS: 2700.0, ZAR: 19.0 });

export const currencyStore = {
  get current() { return currentCurrency; },
  set current(val) { currentCurrency = val; },
  get rates() { return rates; },

  async fetchRates() {
    try {
      const response = await fetch(`${BASE_URL}/currency/rates`);
      if (!response.ok) throw new Error('Failed to fetch rates');
      const result = await response.json();
      if (result.status && result.rates) {
        rates = result.rates;
      }
    } catch (error) {
      console.error('Error fetching currency rates:', error);
    }
  },

  /**
   * Convert USD amount to current currency using EUR-relative rates.
   * @param {number} amount 
   */
  convert(amount) {
    /** @type {Record<string, number>} */
    const currentRates = rates;
    const usdPerEur = currentRates.USD || 1;
    const targetPerEur = currentRates[currentCurrency] || usdPerEur;
    const rateFromUsdToTarget = targetPerEur / usdPerEur;
    return amount * rateFromUsdToTarget;
  },

  /**
   * Format amount with currency symbol
   * @param {number} amount 
   */
  format(amount) {
    const converted = this.convert(amount);
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: currentCurrency,
    }).format(converted);
  }
};
