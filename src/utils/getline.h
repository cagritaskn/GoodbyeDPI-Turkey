#if !HAVE_GETDELIM
// Read a line from stream into buffer, delimited by specified character
ssize_t	getdelim(char **, size_t *, int, FILE *);
#endif

#if !HAVE_GETLINE
// Read a line from stream into buffer, delimited by newline character
ssize_t	getline(char **, size_t *, FILE *);
#endif
