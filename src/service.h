// Windows service management functions for GoodbyeDPI
int service_register(int argc, char *argv[]);    // Register and start the Windows service
void service_main(int argc, char *argv[]);       // Service entry point called by Windows
void service_controlhandler(DWORD request);      // Handle service control events (stop/shutdown)
