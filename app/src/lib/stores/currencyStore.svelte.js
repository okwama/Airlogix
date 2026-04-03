const BASE_URL = import.meta.env.VITE_API_BASE_URL || 'https://impulsepromotions.co.ke/api/airlogix';

// Svelte 5 rune-based store for currency
let currentCurrency = $state('KES');
let rates = $state({ KES: 1, USD: 0.0076, TZS: 19.5, ZAR: 0.14 }); // Default fallback rates

export const currencyStore = {
  get current() { return currentCurrency; },
  set current(val) { currentCurrency = val; },
  get rates() { return rates; },

  async fetchRates() {
    try {
      const response = await fetch(`${BASE_URL}/currency/rates`);
      if (!response.ok) throw new Error('Failed to fetch rates');
      const result = await response.json();
      if (result.status && result.data) {
        rates = result.data;
      }
    } catch (error) {
      console.error('Error fetching currency rates:', error);
    }
  },

  /**
   * Convert KES amount to current currency
   * @param {number} amount 
   */
  convert(amount) {
    /** @type {Record<string, number>} */
    const currentRates = rates;
    const rate = currentRates[currentCurrency] || 1;
    return amount * rate;
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
