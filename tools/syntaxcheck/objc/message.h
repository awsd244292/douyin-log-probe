//
// 语法检查桩：<objc/message.h>
//
// 真机 SDK 里 objc_msgSend 系列声明在这个头文件，不在 <objc/runtime.h>。
// 桩必须与真机保持一致 —— 否则会出现「桩上编译通过、真机编译失败」，
// 而这类失败恰恰是最难查的（本地全绿，上机才炸）。
//
#ifndef _PDP_STUB_OBJC_MESSAGE_H
#define _PDP_STUB_OBJC_MESSAGE_H

#include <objc/runtime.h>

// 可变参数：真机上这是汇编入口，桩里只需要让调用点能通过类型检查。
id objc_msgSend(id self, SEL op, ...);
void objc_msgSendSuper(void);   // 本工程未使用，仅占位保持与真机头文件同构

#endif
