/*
 * random.c
 *		Random functions.
 *
 * Copyright (c) 2001 Marko Kreen
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *	  notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *	  notice, this list of conditions and the following disclaimer in the
 *	  documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.	IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 * $PostgreSQL$
 */


#include <postgres.h>

#include "px.h"


#if defined(RAND_DEV)

#include <errno.h>
#include <fcntl.h>
#include <unistd.h>

static int
safe_read(int fd, void *buf, size_t count)
{
	int			done = 0;
	char	   *p = buf;
	int			res;

	while (count)
	{
		res = read(fd, p, count);
		if (res <= 0)
		{
			if (errno == EINTR)
				continue;
			return PXE_DEV_READ_ERROR;
		}
		p += res;
		done += res;
		count -= res;
	}
	return done;
}

int
px_get_random_bytes(uint8 *dst, unsigned count)
{
	int			fd;
	int			res;

	fd = open(RAND_DEV, O_RDONLY);
	if (fd == -1)
		return PXE_DEV_READ_ERROR;
	res = safe_read(fd, dst, count);
	close(fd);
	return res;
}

int
px_get_pseudo_random_bytes(uint8 *dst, unsigned count)
{
	return px_get_random_bytes(dst, count);
}

#elif defined(RAND_SILLY)

int
px_get_pseudo_random_bytes(uint8 *dst, unsigned count)
{
	int			i;

	for (i = 0; i < count; i++)
		*dst++ = random();
	return i;
}

int
px_get_random_bytes(uint8 *dst, unsigned count)
{
	return PXE_NO_RANDOM;
}

#elif defined(RAND_OPENSSL)

#include <openssl/evp.h>
#include <openssl/blowfish.h>
#include <openssl/rand.h>
#include <openssl/err.h>

static int	openssl_random_init = 0;

/*
 * OpenSSL random should re-feeded occasionally. From /dev/urandom
 * preferably.
 */
static void init_openssl()
{
	if (RAND_get_rand_method() == NULL)
		RAND_set_rand_method(RAND_SSLeay());
	openssl_random_init = 1;
}

int
px_get_random_bytes(uint8 *dst, unsigned count)
{
	int			res;

	if (!openssl_random_init)
		init_openssl();

	res = RAND_bytes(dst, count);
	if (res == 1)
		return count;

	return PXE_OSSL_RAND_ERROR;
}

int
px_get_pseudo_random_bytes(uint8 *dst, unsigned count)
{
	int			res;

	if (!openssl_random_init)
		init_openssl();

	res = RAND_pseudo_bytes(dst, count);
	if (res == 0 || res == 1)
		return count;

	return PXE_OSSL_RAND_ERROR;
}

#else
#error "Invalid random source"
#endif
