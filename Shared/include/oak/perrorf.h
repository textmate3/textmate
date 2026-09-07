#ifndef OAK_PERRORF_H_35H67VAO
#define OAK_PERRORF_H_35H67VAO

// perror with a formatted message: what was being done, then what errno says went wrong.
__attribute__ ((format (printf, 1, 2))) inline void perrorf (char const* format, ...)
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

#endif /* end of include guard: OAK_PERRORF_H_35H67VAO */
