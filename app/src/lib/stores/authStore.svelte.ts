import { authService } from '$lib/services/authService';

interface AuthState {
  user: any | null;
  token: string | null;
  loading: boolean;
}

function createAuthStore() {
  let state = $state<AuthState>({
    user: null,
    token: null,
    loading: true
  });

  async function init() {
    const token = authService.getToken();
    state = { ...state, token, loading: !!token };

    if (!token) {
      state = { ...state, loading: false };
      return;
    }

    try {
      const profile = await authService.fetchProfile();
      state = { ...state, user: profile, loading: false };
    } catch {
      authService.logout();
      state = { user: null, token: null, loading: false };
    }
  }

  async function login(identifier: string, password: string) {
    state = { ...state, loading: true };
    await authService.login({ identifier, password });
    const token = authService.getToken();
    const profile = await authService.fetchProfile();
    state = { user: profile, token, loading: false };
  }

  async function register(payload: {
    phone_number: string;
    password: string;
    first_name: string;
    last_name: string;
    email?: string;
  }) {
    state = { ...state, loading: true };
    await authService.register(payload);
    // After registration, immediately log in
    await login(payload.phone_number, payload.password);
  }

  function logout() {
    authService.logout();
    state = { user: null, token: null, loading: false };
  }

  return {
    get user() {
      return state.user;
    },
    get token() {
      return state.token;
    },
    get loading() {
      return state.loading;
    },
    get isAuthenticated() {
      return !!state.token;
    },
    init,
    login,
    register,
    logout
  };
}

export const authStore = createAuthStore();

