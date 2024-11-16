/**************************************************************************/
/*  rw_lock.h                                                             */
/**************************************************************************/
/*                         This file is part of:                          */
/*                             GODOT ENGINE                               */
/*                        https://godotengine.org                         */
/**************************************************************************/
/* Copyright (c) 2014-present Godot Engine contributors (see AUTHORS.md). */
/* Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur.                  */
/*                                                                        */
/* Permission is hereby granted, free of charge, to any person obtaining  */
/* a copy of this software and associated documentation files (the        */
/* "Software"), to deal in the Software without restriction, including    */
/* without limitation the rights to use, copy, modify, merge, publish,    */
/* distribute, sublicense, and/or sell copies of the Software, and to     */
/* permit persons to whom the Software is furnished to do so, subject to  */
/* the following conditions:                                              */
/*                                                                        */
/* The above copyright notice and this permission notice shall be         */
/* included in all copies or substantial portions of the Software.        */
/*                                                                        */
/* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,        */
/* EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF     */
/* MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. */
/* IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY   */
/* CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,   */
/* TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE      */
/* SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                 */
/**************************************************************************/

#ifndef RW_LOCK_H
#define RW_LOCK_H

#include "core/error_list.h"

#if !defined(NO_THREADS)
#include "core/typedefs.h"
#include <pthread.h>

class RWLock {
private:
    mutable pthread_mutex_t mutex;
    mutable pthread_cond_t read_cv;
    mutable pthread_cond_t write_cv;
    mutable int readers{0};
    mutable bool writing{false};

public:
    RWLock() {
        pthread_mutex_init(&mutex, nullptr);
        pthread_cond_init(&read_cv, nullptr);
        pthread_cond_init(&write_cv, nullptr);
    }

    ~RWLock() {
        pthread_mutex_destroy(&mutex);
        pthread_cond_destroy(&read_cv);
        pthread_cond_destroy(&write_cv);
    }

    void read_lock() const {
        pthread_mutex_lock(&mutex);
        while (writing) {
            pthread_cond_wait(&read_cv, &mutex);
        }
        ++readers;
        pthread_mutex_unlock(&mutex);
    }

    void read_unlock() const {
        pthread_mutex_lock(&mutex);
        --readers;
        if (readers == 0) {
            pthread_cond_signal(&write_cv);
        }
        pthread_mutex_unlock(&mutex);
    }

    void write_lock() {
        pthread_mutex_lock(&mutex);
        while (writing || readers > 0) {
            pthread_cond_wait(&write_cv, &mutex);
        }
        writing = true;
        pthread_mutex_unlock(&mutex);
    }

    void write_unlock() {
        pthread_mutex_lock(&mutex);
        writing = false;
        pthread_cond_broadcast(&read_cv);  // Notify all readers
        pthread_cond_signal(&write_cv);    // Notify one writer
        pthread_mutex_unlock(&mutex);
    }
};

#else

class RWLock {
public:
	void read_lock() const {}
	void read_unlock() const {}
	Error read_try_lock() const { return OK; }

	void write_lock() {}
	void write_unlock() {}
	Error write_try_lock() { return OK; }
};

#endif

class RWLockRead {
	const RWLock &lock;

public:
	_ALWAYS_INLINE_ RWLockRead(const RWLock &p_lock) :
			lock(p_lock) {
		lock.read_lock();
	}
	_ALWAYS_INLINE_ ~RWLockRead() {
		lock.read_unlock();
	}
};

class RWLockWrite {
	RWLock &lock;

public:
	_ALWAYS_INLINE_ RWLockWrite(RWLock &p_lock) :
			lock(p_lock) {
		lock.write_lock();
	}
	_ALWAYS_INLINE_ ~RWLockWrite() {
		lock.write_unlock();
	}
};

#endif // RW_LOCK_H
