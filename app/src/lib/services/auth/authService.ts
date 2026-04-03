import { BASE_URL } from '$lib/services/booking/bookingService';

export interface RegisterPayload {
  phone_number: string;
  password: string;
  first_name: string;
  last_name: string;
  email?: string;
}

export interface LoginPayload {
  identifier: string; // phone_number or email
  password: string;
}

export interface AuthResponse {
  status: boolean;
  token?: string;
  message?: string;
  data?: any;
}

const TOKEN_KEY = 'airlogix_jwt';

export const authService = {
  getToken(): string | null {
    if (typeof localStorage === 'undefined') return null;
    return localStorage.getItem(TOKEN_KEY);
  },

  setToken(token: string | null) {
    if (typeof localStorage === 'undefined') return;
    if (!token) {
      localStorage.removeItem(TOKEN_KEY);
    } else {
      localStorage.setItem(TOKEN_KEY, token);
    }
  },

  async register(payload: RegisterPayload): Promise<void> {
    const res = await fetch(`${BASE_URL}/auth/register`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload)
    });
    const result: AuthResponse = await res.json();
    if (!res.ok || !result.status) {
      throw new Error(result.message || 'Failed to create account');
    }
  },

  async login(payload: LoginPayload): Promise<void> {
    const res = await fetch(`${BASE_URL}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload)
    });
    const result: AuthResponse = await res.json();
    if (!res.ok || !result.status || !result.token) {
      throw new Error(result.message || 'Invalid credentials');
    }
    this.setToken(result.token);
  },

  async fetchProfile(): Promise<any | null> {
    const token = this.getToken();
    if (!token) return null;

    const res = await fetch(`${BASE_URL}/auth/profile`, {
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${token}`
      }
    });

    if (res.status === 401) {
      this.setToken(null);
      return null;
    }

    const result = await res.json();
    if (!res.ok || !result.status) {
      return null;
    }

    return result.data;
  },

  logout() {
    this.setToken(null);
  }
};

