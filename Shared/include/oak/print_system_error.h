#ifndef OAK_PRINT_SYSTEM_ERROR_H_35H67VAO
#define OAK_PRINT_SYSTEM_ERROR_H_35H67VAO

// Prints what was being done, then what errno says went wrong, to standard error.
// print_system_error("saveBackup: write") prints "saveBackup: write: No space left on device".
__attribute__ ((format (printf, 1, 2))) inline void print_system_error (char const* format, ...)
{
	char* err = strerror(errno);
	char* msg = NULL;

	va_list ap;
	va_start(ap, format);
	vasprintf(&msg, format, ap);
	va_end(ap);

	fprintf(stderr, "%s: %s\n", msg, err);
	free(msg);
}

#endif /* end of include guard: OAK_PRINT_SYSTEM_ERROR_H_35H67VAO */
