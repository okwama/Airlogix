import { BASE_URL } from '$lib/services/booking/bookingService';

let unreadCountCache: { token: string; value: number; expiresAt: number } | null = null;
let unreadCountPromise: Promise<number> | null = null;

function getAuthHeaders(token?: string | null): Record<string, string> {
  if (!token) {
    throw new Error('Authentication required');
  }

  return {
    Authorization: `Bearer ${token}`
  };
}

async function readJson(response: Response) {
  const result = await response.json();
  if (!response.ok || !result.status) {
    throw new Error(result.message || 'Request failed');
  }
  return result;
}

export const accountService = {
  async fetchProfile(token?: string | null) {
    const response = await fetch(`${BASE_URL}/auth/profile`, {
      headers: {
        'Content-Type': 'application/json',
        ...getAuthHeaders(token)
      }
    });
    const result = await readJson(response);
    return result.data;
  },

  async updateProfile(payload: Record<string, unknown>, token?: string | null) {
    const response = await fetch(`${BASE_URL}/auth/profile`, {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
        ...getAuthHeaders(token)
      },
      body: JSON.stringify(payload)
    });
    return readJson(response);
  },

  async changePassword(currentPassword: string, newPassword: string, token?: string | null) {
    const response = await fetch(`${BASE_URL}/auth/password`, {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
        ...getAuthHeaders(token)
      },
      body: JSON.stringify({
        current_password: currentPassword,
        new_password: newPassword
      })
    });
    return readJson(response);
  },

  async deleteAccount(token?: string | null) {
    const response = await fetch(`${BASE_URL}/auth/delete-account`, {
      method: 'DELETE',
      headers: {
        'Content-Type': 'application/json',
        ...getAuthHeaders(token)
      }
    });
    return readJson(response);
  },

  async uploadProfilePhoto(file: File, token?: string | null) {
    if (!token) {
      throw new Error('Authentication required');
    }

    const formData = new FormData();
    formData.append('photo', file);

    const response = await fetch(`${BASE_URL}/auth/profile-photo`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${token}`
      },
      body: formData
    });

    const result = await readJson(response);
    return result.data;
  },

  async fetchLoyaltyInfo(token?: string | null) {
    const response = await fetch(`${BASE_URL}/loyalty/info`, {
      headers: {
        'Content-Type': 'application/json',
        ...getAuthHeaders(token)
      }
    });
    const result = await readJson(response);
    return result.data;
  },

  async fetchLoyaltyHistory(token?: string | null) {
    const response = await fetch(`${BASE_URL}/loyalty/history`, {
      headers: {
        'Content-Type': 'application/json',
        ...getAuthHeaders(token)
      }
    });
    const result = await readJson(response);
    return result.data || [];
  },

  async fetchNotifications(token?: string | null, limit = 20) {
    const response = await fetch(`${BASE_URL}/notifications?limit=${encodeURIComponent(String(limit))}`, {
      headers: {
        'Content-Type': 'application/json',
        ...getAuthHeaders(token)
      }
    });
    const result = await readJson(response);
    return result.data || [];
  },

  async fetchUnreadCount(token?: string | null) {
    if (!token) {
      throw new Error('Authentication required');
    }

    const now = Date.now();
    if (unreadCountCache && unreadCountCache.token === token && unreadCountCache.expiresAt > now) {
      return unreadCountCache.value;
    }

    if (unreadCountPromise) {
      return unreadCountPromise;
    }

    unreadCountPromise = (async () => {
      const response = await fetch(`${BASE_URL}/notifications/unread-count`, {
        headers: {
          'Content-Type': 'application/json',
          ...getAuthHeaders(token)
        }
      });
      const result = await readJson(response);
      const value = Number(result.data?.unread_count || 0);
      unreadCountCache = {
        token,
        value,
        expiresAt: Date.now() + 30000
      };
      return value;
    })();

    try {
      return await unreadCountPromise;
    } finally {
      unreadCountPromise = null;
    }
  },

  async markNotificationRead(id: number, token?: string | null) {
    const response = await fetch(`${BASE_URL}/notifications/read/${id}`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        ...getAuthHeaders(token)
      }
    });
    if (unreadCountCache && token && unreadCountCache.token === token) {
      unreadCountCache = {
        ...unreadCountCache,
        value: Math.max(0, unreadCountCache.value - 1),
        expiresAt: Date.now() + 10000
      };
    }
    return readJson(response);
  },

  async markAllNotificationsRead(token?: string | null) {
    const response = await fetch(`${BASE_URL}/notifications/read-all`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        ...getAuthHeaders(token)
      }
    });
    if (unreadCountCache && token && unreadCountCache.token === token) {
      unreadCountCache = {
        ...unreadCountCache,
        value: 0,
        expiresAt: Date.now() + 10000
      };
    }
    return readJson(response);
  },

  async listCargoShipments(token?: string | null) {
    const response = await fetch(`${BASE_URL}/cargo`, {
      headers: {
        'Content-Type': 'application/json',
        ...getAuthHeaders(token)
      }
    });
    const result = await readJson(response);
    return result.data || [];
  }
};
