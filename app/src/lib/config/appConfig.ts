const env = import.meta.env;

const appName = env.VITE_APP_NAME || 'Mc Aviation';

export const appConfig = {
  name: appName,
  description:
    env.VITE_APP_DESCRIPTION ||
    `${appName} is a regional airline that operates flights within East, Central, and Southern Africa.`,
  keywords:
    env.VITE_APP_KEYWORDS ||
    `${appName}, regional airline, flights, booking, tickets, travel`,
  url: env.VITE_APP_URL || 'https://airlogix-smoky.vercel.app/',
  image: env.VITE_APP_IMAGE || env.VITE_APP_ICON || '/favicon.png',
  icon: env.VITE_APP_ICON || env.VITE_APP_IMAGE || '/favicon.png',
  favicon: env.VITE_APP_FAVICON || env.VITE_APP_ICON || '/favicon.png',
  themeColor: env.VITE_APP_THEME_COLOR || '#282F7E',
  backgroundColor: env.VITE_APP_BACKGROUND_COLOR || '#F5F7FA',
  textColor: env.VITE_APP_TEXT_COLOR || '#121212',
  secondaryColor: env.VITE_APP_SECONDARY_COLOR || '#666666',
  borderColor: env.VITE_APP_BORDER_COLOR || '#E0E0E0',
  successColor: env.VITE_APP_SUCCESS_COLOR || '#4CAF50',
  warningColor: env.VITE_APP_WARNING_COLOR || '#FFC107',
  errorColor: env.VITE_APP_ERROR_COLOR || '#F44336',
  defaultCurrency: (env.VITE_APP_DEFAULT_CURRENCY || 'USD').toUpperCase()
};

