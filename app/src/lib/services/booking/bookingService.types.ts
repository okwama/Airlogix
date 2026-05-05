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
}

export interface BookingPayload {
  flight_series_id: number;
  cabin_class_id?: number;
  passengers: Passenger[];
  payment_method?: string;
  total_amount?: number;
  contact_phone?: string;
  contact_email?: string;
  luggage?: {
    checked_bags?: number;
    special_items?: number;
  };
}
