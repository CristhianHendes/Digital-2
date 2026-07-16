void my_busy_wait( unsigned int ms );
void set_power_supply( void );
void read_samples( void );
void init_adc( void );
void send_data_to_UDP( void ); 
void write_memory_32( uint32_t address, uint32_t value );
uint32_t read_memory_32(uint32_t address);