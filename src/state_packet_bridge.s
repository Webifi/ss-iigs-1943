; flight_state_packet: the JSR entry of flight_state_packet_far (flight_loop).
.a8
.i16
flight_state_packet:
  jsl flight_state_packet_far
  rts
