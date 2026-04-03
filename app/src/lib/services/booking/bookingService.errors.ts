export type ServiceErrorType =
  | 'AUTH_EXPIRED'
  | 'HOLD_EXPIRED'
  | 'NOT_FOUND'
  | 'NETWORK'
  | 'VALIDATION'
  | 'RATE_LIMITED'
  | 'SERVER'
  | 'UNKNOWN';

export class ServiceError extends Error {
  type: ServiceErrorType;
  status?: number;
  details?: unknown;
  code?: string;

  constructor(message: string, type: ServiceErrorType, status?: number, details?: unknown, code?: string) {
    super(message);
    this.name = 'ServiceError';
    this.type = type;
    this.status = status;
    this.details = details;
    this.code = code;
  }
}

function isServiceError(error: unknown): error is ServiceError {
  return error instanceof ServiceError;
}

export function asServiceError(error: unknown, fallbackMessage: string): ServiceError {
  if (isServiceError(error)) return error;
  if (error instanceof TypeError) {
    return new ServiceError('Network error. Please check your connection and try again.', 'NETWORK');
  }
  return new ServiceError(error instanceof Error ? error.message : fallbackMessage, 'UNKNOWN');
}

function buildServiceError(
  message: string,
  type: ServiceErrorType,
  status: number,
  details?: unknown,
  code?: string
): ServiceError {
  return new ServiceError(message, type, status, details, code);
}

export function classifyError(
  status: number,
  message: string,
  details?: unknown,
  code?: string
): ServiceError {
  const normalizedCode = (code || '').toUpperCase();
  const normalized = message.toLowerCase();
  if (normalizedCode === 'AUTH_UNAUTHORIZED' || normalizedCode === 'BOOKING_ACCESS_DENIED') {
    return buildServiceError(
      'Your booking access session expired. Please verify again via Manage Booking.',
      'AUTH_EXPIRED',
      status,
      details,
      normalizedCode
    );
  }
  if (normalizedCode === 'BOOKING_HOLD_EXPIRED') {
    return buildServiceError(
      message || 'This reservation has expired. Please search again to create a new booking.',
      'HOLD_EXPIRED',
      status,
      details,
      normalizedCode
    );
  }
  if (
    normalizedCode === 'BOOKING_NOT_FOUND' ||
    normalizedCode === 'PAYMENT_TRANSACTION_NOT_FOUND' ||
    normalizedCode === 'CARGO_BOOKING_NOT_FOUND' ||
    normalizedCode === 'FLIGHT_NOT_FOUND'
  ) {
    return buildServiceError(message || 'Booking not found.', 'NOT_FOUND', status, details, normalizedCode);
  }
  if (normalizedCode === 'BOOKING_ACCESS_RATE_LIMITED') {
    return buildServiceError(message || 'Too many requests. Please try again shortly.', 'RATE_LIMITED', status, details, normalizedCode);
  }
  if (
    normalizedCode === 'PAYMENT_INIT_MISSING_FIELDS' ||
    normalizedCode === 'PAYMENT_REFERENCE_REQUIRED' ||
    normalizedCode === 'PAYMENT_AMOUNT_MISMATCH' ||
    normalizedCode === 'BOOKING_AMOUNT_INVALID' ||
    normalizedCode === 'PAYMENT_METHOD_UNSUPPORTED' ||
    normalizedCode === 'PAYMENT_EMAIL_INVALID' ||
    normalizedCode === 'CURRENCY_INVALID' ||
    normalizedCode === 'BOOKING_CREATE_MISSING_FIELDS' ||
    normalizedCode === 'BOOKING_FIND_INPUT_INVALID' ||
    normalizedCode === 'BOOKING_FIND_NAME_MISMATCH' ||
    normalizedCode === 'CARGO_BOOKING_MISSING_FIELD' ||
    normalizedCode === 'CARGO_AVAILABILITY_INPUT_INVALID' ||
    normalizedCode === 'CARGO_AVAILABILITY_WEIGHT_INVALID' ||
    normalizedCode === 'FLIGHT_SEARCH_INPUT_INVALID' ||
    normalizedCode === 'BOOKING_ACCESS_INPUT_INVALID' ||
    normalizedCode === 'BOOKING_ACCESS_CODE_INVALID' ||
    normalizedCode === 'BOOKING_ALREADY_PAID' ||
    normalizedCode === 'PAYMENT_NOT_SUCCESSFUL'
  ) {
    return buildServiceError(message || 'Please check your details and try again.', 'VALIDATION', status, details, normalizedCode);
  }
  if (
    normalizedCode === 'PAYMENT_PROVIDER_INIT_FAILED' ||
    normalizedCode === 'PAYMENT_VERIFY_FAILED' ||
    normalizedCode === 'PAYMENT_UPDATE_FAILED' ||
    normalizedCode === 'BOOKING_ACCESS_DELIVERY_FAILED' ||
    normalizedCode === 'BOOKING_CREATE_FAILED' ||
    normalizedCode === 'BOOKING_LINK_FAILED' ||
    normalizedCode === 'CARGO_BOOKING_CREATE_FAILED' ||
    normalizedCode === 'CURRENCY_CONVERSION_UNAVAILABLE' ||
    normalizedCode === 'PDF_NOT_CONFIGURED' ||
    normalizedCode === 'PDF_GENERATION_FAILED'
  ) {
    return buildServiceError(message || 'Server error. Please try again in a moment.', 'SERVER', status, details, normalizedCode);
  }

  if (status === 401 || status === 403) {
    return buildServiceError(
      'Your booking access session expired. Please verify again via Manage Booking.',
      'AUTH_EXPIRED',
      status,
      details,
      normalizedCode
    );
  }
  if (status === 404) {
    return buildServiceError(message || 'Booking not found.', 'NOT_FOUND', status, details, normalizedCode);
  }
  if (status === 409 && normalized.includes('expired')) {
    return buildServiceError(
      message || 'This reservation has expired. Please search again to create a new booking.',
      'HOLD_EXPIRED',
      status,
      details,
      normalizedCode
    );
  }
  if (status === 400 || status === 422) {
    return buildServiceError(message || 'Please check your details and try again.', 'VALIDATION', status, details, normalizedCode);
  }
  if (status === 429) {
    return buildServiceError(message || 'Too many requests. Please try again shortly.', 'RATE_LIMITED', status, details, normalizedCode);
  }
  if (status >= 500) {
    return buildServiceError(message || 'Server error. Please try again in a moment.', 'SERVER', status, details, normalizedCode);
  }
  return buildServiceError(message || 'Request failed.', 'UNKNOWN', status, details, normalizedCode);
}

export function extractErrorMeta(payload: any): { message: string; details?: unknown; code?: string } {
  const err = payload?.error ?? {};
  return {
    message: payload?.message || err?.message || 'Request failed.',
    details: err?.details ?? payload?.details,
    code: err?.code ?? payload?.code
  };
}
