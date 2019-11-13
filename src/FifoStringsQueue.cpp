/*
 *
 * (C) 2014-19 - ntop.org
 *
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 *
 */

#include "ntop_includes.h"

#define DEBUG_FIFO_QUEUE

FifoStringsQueue::FifoStringsQueue(u_int32_t queue_size) {
  m = new Mutex();
  size = queue_size;
  head = tail = 0;
  cur_items = 0;

  items = (char**)calloc(size, sizeof(char**));
  if(items == NULL) throw 1;
}

/* ******************************************* */

FifoStringsQueue::~FifoStringsQueue() {
  delete m;

  while(head != tail) {
    if(items[head])
      free(items[head]);

    cur_items--;

#ifdef DEBUG_FIFO_QUEUE
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Queue free [pos=%d, remaining=%d]", head, cur_items);
#endif

    if(++head >= size)
      head = 0;
  }

  free(items);
}

/* ******************************************* */

/* NOTE: strdup is performed internally. */
bool FifoStringsQueue::enqueue(const char *item) {
  bool rv = false;

  m->lock(__FILE__, __LINE__);

  if(canEnqueue() && item) {
    items[tail] = strdup(item);

    if(items[tail]) {
      rv = true;
      cur_items++;
#ifdef DEBUG_FIFO_QUEUE
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "Enqueue [pos=%d, new_length=%d]", tail, cur_items);
#endif

      if(++tail >= size)
        tail = 0;
    }
  } else {
#ifdef DEBUG_FIFO_QUEUE
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Enqueue: queue full [%d items], skipping", cur_items);
#endif
  }

  m->unlock(__FILE__, __LINE__);
  return(rv);
}

/* ******************************************* */

/* NOTE: the caller should free the returned string */
char* FifoStringsQueue::dequeue() {
  char *rv;

  if(!cur_items) {
#ifdef DEBUG_FIFO_QUEUE
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Dequeue: no items [head=%d, tail=%d]", head, tail);
#endif
    return(NULL);
  }

  m->lock(__FILE__, __LINE__);

  rv = items[head];
  items[head] = NULL;

  cur_items--;

#ifdef DEBUG_FIFO_QUEUE
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Dequeue: [pos=%d, item=%s, remaining=%d]", head, rv, cur_items);
#endif

  if(++head >= size)
    head = 0;

  m->unlock(__FILE__, __LINE__);
  return(rv);
}
