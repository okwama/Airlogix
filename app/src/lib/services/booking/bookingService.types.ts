export interface Passenger {
  first_name: string;
  last_name: string;
  passenger_type: 'adult' | 'child' | 'infant';
  email?: string;
  phone?: string;
  title?: string;
  date_of_birth?: string;
  passport_number?: string;
  nationality?: string;
  identification?: string;
  age?: number | string;
}

export interface BookingPayload {
  flight_series_id: number;
  cabin_class_id?: number;
  passengers: Passenger[];
  payment_method?: string;
  total_amount?: number;
  booking_date?: string | null;
  contact_phone?: string;
  contact_email?: string;
  is_return_trip?: number;
  return_flight_series_id?: number | null;
  return_date?: string | null;
  luggage?: {
    checked_bags?: number;
    special_items?: number;
  };
}
