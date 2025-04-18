// RUN: %target-swift-emit-irgen                                            \
// RUN:     %s                                                              \
// RUN:     -Onone                                                          \
// RUN:     -enable-experimental-feature CoroutineAccessors                 \
// RUN:     -enable-arm64-corocc                                            \
// RUN:     -enable-x86_64-corocc                                           \
// RUN: | %IRGenFileCheck %s

// REQUIRES: CPU=arm64 || CPU=arm64e || CPU=x86_64
// REQUIRES: swift_feature_CoroutineAccessors

// CHECK-LABEL: @"$s27coroutine_accessors_popless1iSivxTwc" = {{.*}}global{{.*}} %swift.coro_func_pointer <{
//           :    sub (
// CHECK-SAME:      $s27coroutine_accessors_popless1iSivx
//           :      $s27coroutine_accessors_popless1iSivxTwc
//           :    ),
// CHECK-SAME:    i32 0
// CHECK-SAME:  }>

// CHECK-LABEL: _swift_coro_async_allocator = linkonce_odr hidden constant %swift.coro_allocator {
// CHECK-SAME:      i32 1,
// CHECK-SAME:      swift_task_alloc,
// CHECK-SAME:      swift_task_dealloc
// CHECK-SAME:  }
// CHECK-LABEL: _swift_coro_malloc_allocator = linkonce_odr hidden constant %swift.coro_allocator {
// CHECK-SAME:       i32 2,
// CHECK-SAME:       malloc,
// CHECK-SAME:       free
// CHECK-SAME:  }

// CHECK-LABEL: @__swift_coro_alloc_(
// CHECK-SAME:      ptr [[ALLOCATOR:%[^,]+]]
// CHECK-SAME:      i64 [[SIZE:%[^)]+]]
// CHECK-SAME:  )
// CHECK-SAME:  {
// CHECK:       entry:
// CHECK:         [[USE_POPLESS:%[^,]+]] = icmp eq ptr [[ALLOCATOR]], null
// CHECK:         br i1 [[USE_POPLESS]],
// CHECK-SAME:        label %coro.return.popless
// CHECK-SAME:        label %coro.return.normal
// CHECK:       coro.return.popless:
// CHECK:         [[STACK_ALLOCATION:%[^,]+]] = alloca i8, i64 [[SIZE]]
// CHECK:         musttail call void @llvm.ret.popless()
// CHECK:         ret ptr [[STACK_ALLOCATION]]
// CHECK:       coro.return.normal:
// CHECK:         [[OTHER_ALLOCATION:%[^,]+]] = call swiftcc ptr @swift_coro_alloc(
// CHECK-SAME:        ptr [[ALLOCATOR]]
// CHECK-SAME:        i64 [[SIZE]]
// CHECK-SAME:    )
// CHECK:         ret ptr [[OTHER_ALLOCATION]]
// CHECK:       }

public var _i: Int = 0

public var i: Int {
  read {
    yield _i
  }
  modify {
    yield &_i
  }
}

// CHECK-LABEL: define{{.*}} void @increment_i(
// CHECK-SAME:  )
// CHECK-SAME:  {
//      :         [[SIZE_32:%[^,]+]] = load i32
//           :        ptr getelementptr inbounds (
//           :            %swift.coro_func_pointer
// CHECK:                 $s27coroutine_accessors_popless1iSivxTwc
//           :            i32 0
//           :            i32 1
//           :        )
// CHECK-64:      [[SIZE_64:%[^,]+]] = zext i32 {{%[^,]+}} to i64
// CHECK-64:      [[FRAME:%[^,]+]] = alloca i8, [[INT]] [[SIZE_64]]
// CHECK:         call void @llvm.lifetime.start.p0(i64 -1, ptr [[FRAME]])
// CHECK:         [[RAMP:%[^,]+]] = call ptr @llvm.coro.prepare.retcon(ptr @"$s27coroutine_accessors_popless1iSivx")
// CHECK:         [[RETVAL:%[^,]+]] = call swiftcorocc { ptr, ptr } [[RAMP]](
// CHECK-SAME:         [[FRAME]],
// CHECK-SAME:         null
// CHECK-SAME:    )
// CHECK:         [[CONTINUATION:%[^,]+]] = extractvalue { ptr, ptr } [[RETVAL]], 0
// CHECK:         [[YIELD:%[^,]+]] = extractvalue { ptr, ptr } [[RETVAL]], 1
// CHECK:         call swiftcc void @"$s27coroutine_accessors_popless9incrementyySizF"(
// CHECK-SAME:        [[YIELD]]
// CHECK-SAME:    )
// CHECK:         call swiftcorocc void [[CONTINUATION]](
// CHECK-SAME:        [[FRAME]],
// CHECK-SAME:        null
// CHECK-SAME:    )
// CHECK:         call void @llvm.lifetime.end.p0(i64 -1, ptr [[FRAME]])
// CHECK:       }
@_silgen_name("increment_i")
public func increment_i() {
  increment(&i)
}

public func increment(_ int: inout Int) {
  int += 1
}

// CHECK-LABEL: define{{.*}} void @increment_i_async(
//                  ptr swiftasync %0
// CHECK-SAME:  )
// CHECK-SAME:  {
//      :         [[SIZE_32:%[^,]+]] = load i32
//           :        ptr getelementptr inbounds (
//           :            %swift.coro_func_pointer
// CHECK:                 $s27coroutine_accessors_popless1iSivxTwc
//           :            i32 0
//           :            i32 1
//           :        )
// CHECK:         [[SIZE_RAW:%[^,]+]] = zext i32 {{%[^,]+}} to i64
// CHECK:         [[SIZE_1:%[^,]+]] = add i64 [[SIZE_RAW]], 15
// CHECK:         [[SIZE:%[^,]+]] = and i64 [[SIZE_1]], -16
// CHECK:         [[FRAME:%[^,]+]] = call swiftcc ptr @swift_task_alloc(i64 [[SIZE]])
// CHECK:         call void @llvm.lifetime.start.p0(i64 -1, ptr [[FRAME]])
// CHECK:         [[RAMP:%[^,]+]] = call ptr @llvm.coro.prepare.retcon(ptr @"$s27coroutine_accessors_popless1iSivx")
// CHECK:         [[RETVAL:%[^,]+]] = call swiftcorocc { ptr, ptr } [[RAMP]](
// CHECK-SAME:         [[FRAME]],
// CHECK-SAME:         _swift_coro_async_allocator
// CHECK-SAME:    )
// CHECK:         [[CONTINUATION:%[^,]+]] = extractvalue { ptr, ptr } [[RETVAL]], 0
// CHECK:         [[YIELD:%[^,]+]] = extractvalue { ptr, ptr } [[RETVAL]], 1

//                increment_async([[YIELD]])

// CHECK:         call swiftcorocc void [[CONTINUATION]](
// CHECK-SAME:        [[FRAME]],
// CHECK-SAME:        _swift_coro_async_allocator
// CHECK-SAME:    )
// CHECK:         call void @llvm.lifetime.end.p0(i64 -1, ptr [[FRAME]])
// CHECK:         call swiftcc void @swift_task_dealloc_through(ptr [[FRAME]])
// CHECK:       }
@_silgen_name("increment_i_async")
public func increment_i_async() async {
  await increment_async(&i)
}

public func increment_async(_ int: inout Int) async {
  int += 1
}

public var force_yield_once_convention : () {
  _read {
    let nothing: () = ()
    yield nothing
  }
// CHECK-LABEL: define{{.*}} { ptr, ptr } @increment_i_yield_once(
//                  ptr noalias dereferenceable(32) %0
// CHECK-SAME:  )
// CHECK-SAME:  {
//      :         [[SIZE_32:%[^,]+]] = load i32
//           :        ptr getelementptr inbounds (
//           :            %swift.coro_func_pointer
// CHECK:                 $s27coroutine_accessors_popless1iSivxTwc
//           :            i32 0
//           :            i32 1
//           :        )
// CHECK:         [[SIZE:%[^,]+]] = zext i32 {{%[^,]+}} to i64
// CHECK:         [[ALLOCATION:%[^,]+]] = call token @llvm.coro.alloca.alloc.i64(i64 [[SIZE]], i32 16)
// CHECK:         [[FRAME:%[^,]+]] = call ptr @llvm.coro.alloca.get(token [[ALLOCATION]])
// CHECK:         call void @llvm.lifetime.start.p0(i64 -1, ptr [[FRAME]])
// CHECK:         [[RAMP:%[^,]+]] = call ptr @llvm.coro.prepare.retcon(ptr @"$s27coroutine_accessors_popless1iSivx")
// CHECK:         [[RETVAL:%[^,]+]] = call swiftcorocc { ptr, ptr } [[RAMP]](
// CHECK-SAME:         [[FRAME]],
// CHECK-SAME:         _swift_coro_malloc_allocator
// CHECK-SAME:    )
// CHECK:         [[CONTINUATION:%[^,]+]] = extractvalue { ptr, ptr } [[RETVAL]], 0
// CHECK:         [[YIELD:%[^,]+]] = extractvalue { ptr, ptr } [[RETVAL]], 1
// CHECK:         call swiftcc void @"$s27coroutine_accessors_popless9incrementyySizF"(
// CHECK-SAME:        [[YIELD]]
// CHECK-SAME:    )
// CHECK:         call swiftcorocc void [[CONTINUATION]](
// CHECK-SAME:        [[FRAME]],
// CHECK-SAME:        _swift_coro_malloc_allocator
// CHECK-SAME:    )
// CHECK:         call void @llvm.lifetime.end.p0(i64 -1, ptr [[FRAME]])
// CHECK:         call void @llvm.coro.alloca.free(token [[ALLOCATION]])
// CHECK:       }
  @_silgen_name("increment_i_yield_once")
  _modify {
    increment(&i)

    var nothing: () = ()
    yield &nothing
  }
}

public var force_yield_once_2_convention : () {
  read {
    let nothing: () = ()
    yield nothing
  }
// CHECK-LABEL: define{{.*}} { ptr, ptr } @increment_i_yield_once_2(
//                  ptr noalias %0
// CHECK-SAME:      ptr [[ALLOCATOR:%[^)]+]]
// CHECK-SAME:  )
// CHECK-SAME:  {
//      :         [[SIZE_32:%[^,]+]] = load i32
//           :        ptr getelementptr inbounds (
//           :            %swift.coro_func_pointer
// CHECK:                 $s27coroutine_accessors_popless1iSivxTwc
//           :            i32 0
//           :            i32 1
//           :        )
// CHECK:         [[SIZE:%[^,]+]] = zext i32 {{%[^,]+}} to i64
// CHECK:         [[ALLOCATION:%[^,]+]] = call token @llvm.coro.alloca.alloc.i64(i64 [[SIZE]], i32 16)
// CHECK:         [[FRAME:%[^,]+]] = call ptr @llvm.coro.alloca.get(token [[ALLOCATION]])
// CHECK:         call void @llvm.lifetime.start.p0(i64 -1, ptr [[FRAME]])
// CHECK:         [[RAMP:%[^,]+]] = call ptr @llvm.coro.prepare.retcon(ptr @"$s27coroutine_accessors_popless1iSivx")
// CHECK:         [[RETVAL:%[^,]+]] = call swiftcorocc { ptr, ptr } [[RAMP]](
// CHECK-SAME:         [[FRAME]],
// CHECK-SAME:         [[ALLOCATOR]]
// CHECK-SAME:    )
// CHECK:         [[CONTINUATION:%[^,]+]] = extractvalue { ptr, ptr } [[RETVAL]], 0
// CHECK:         [[YIELD:%[^,]+]] = extractvalue { ptr, ptr } [[RETVAL]], 1
// CHECK:         call swiftcc void @"$s27coroutine_accessors_popless9incrementyySizF"(
// CHECK-SAME:        [[YIELD]]
// CHECK-SAME:    )
// CHECK:         call swiftcorocc void [[CONTINUATION]](
// CHECK-SAME:        [[FRAME]],
// CHECK-SAME:        [[ALLOCATOR]]
// CHECK-SAME:    )
// CHECK:         call void @llvm.lifetime.end.p0(i64 -1, ptr [[FRAME]])
// CHECK:         call void @llvm.coro.alloca.free(token [[ALLOCATION]])
// CHECK:       }
  @_silgen_name("increment_i_yield_once_2")
  modify {
    increment(&i)

    var nothing: () = ()
    yield &nothing
  }
}
