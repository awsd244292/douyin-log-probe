// 语法检查用最小桩：libdispatch
#ifndef PDP_STUB_DISPATCH_H
#define PDP_STUB_DISPATCH_H

#include <stdint.h>
#include <stddef.h>

typedef void (^dispatch_block_t)(void);
typedef id dispatch_queue_t;
typedef long dispatch_once_t;
typedef uint64_t dispatch_time_t;

#define DISPATCH_TIME_NOW 0
#define NSEC_PER_SEC 1000000000ull

dispatch_time_t dispatch_time(dispatch_time_t when, int64_t delta);
void dispatch_once(dispatch_once_t *predicate, dispatch_block_t block);
void dispatch_async(dispatch_queue_t queue, dispatch_block_t block);
void dispatch_sync(dispatch_queue_t queue, dispatch_block_t block);
void dispatch_after(dispatch_time_t when, dispatch_queue_t queue, dispatch_block_t block);
dispatch_queue_t dispatch_get_main_queue(void);
dispatch_queue_t dispatch_get_global_queue(long identifier, unsigned long flags);
typedef void *dispatch_queue_attr_t;
dispatch_queue_t dispatch_queue_create(const char *label, dispatch_queue_attr_t attr);
#define DISPATCH_QUEUE_SERIAL NULL
void dispatch_set_target_queue(dispatch_queue_t queue, dispatch_queue_t target);

// QoS 类（dispatch_get_global_queue 的 identifier，V3.0.9 抓栈队列用）
#define QOS_CLASS_USER_INTERACTIVE 0x21
#define QOS_CLASS_USER_INITIATED 0x19
#define QOS_CLASS_UTILITY 0x11
#define QOS_CLASS_BACKGROUND 0x09

// 全局队列优先级（dispatch_get_global_queue 的 identifier）
#define DISPATCH_QUEUE_PRIORITY_HIGH 2
#define DISPATCH_QUEUE_PRIORITY_DEFAULT 0
#define DISPATCH_QUEUE_PRIORITY_LOW (-2)
#define DISPATCH_QUEUE_PRIORITY_BACKGROUND INT16_MIN

// DLP 补：dispatch_source 定时器（真机 SDK 有，桩补齐防误报）
typedef id dispatch_source_t;
#define DISPATCH_SOURCE_TYPE_TIMER ((void *)1)
dispatch_source_t dispatch_source_create(const void *type, uintptr_t handle,
                                         unsigned long mask, dispatch_queue_t queue);
void dispatch_source_set_timer(dispatch_source_t source, dispatch_time_t start,
                               uint64_t interval, uint64_t leeway);
void dispatch_source_set_event_handler(dispatch_source_t source, dispatch_block_t handler);
void dispatch_source_cancel(dispatch_source_t source);
void dispatch_resume(id object);

#endif
