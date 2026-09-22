	.text
	.file	"basic.cpp"
	.globl	_Z9load_treePKc                 # -- Begin function _Z9load_treePKc
	.p2align	4, 0x90
	.type	_Z9load_treePKc,@function
_Z9load_treePKc:                        # @_Z9load_treePKc
.Lfunc_begin0:
	.cfi_startproc
	.cfi_personality 155, DW.ref.__gxx_personality_v0
	.cfi_lsda 27, .Lexception0
# %bb.0:
	pushq	%r15
	.cfi_def_cfa_offset 16
	pushq	%r14
	.cfi_def_cfa_offset 24
	pushq	%r13
	.cfi_def_cfa_offset 32
	pushq	%r12
	.cfi_def_cfa_offset 40
	pushq	%rbx
	.cfi_def_cfa_offset 48
	subq	$544, %rsp                      # imm = 0x220
	.cfi_def_cfa_offset 592
	.cfi_offset %rbx, -48
	.cfi_offset %r12, -40
	.cfi_offset %r13, -32
	.cfi_offset %r14, -24
	.cfi_offset %r15, -16
	movq	%rdi, %rsi
	leaq	24(%rsp), %rbx
	movq	%rbx, %rdi
	movl	$8, %edx
	callq	_ZNSt14basic_ifstreamIcSt11char_traitsIcEEC1EPKcSt13_Ios_Openmode@PLT
.Ltmp0:
	leaq	12(%rsp), %rsi
	movq	%rbx, %rdi
	callq	_ZNSirsERi@PLT
.Ltmp1:
# %bb.1:
	movslq	12(%rsp), %rbx
	testq	%rbx, %rbx
	js	.LBB0_2
# %bb.4:
	leaq	(,%rbx,8), %r14
.Ltmp3:
	movq	%r14, %rdi
	callq	_Znwm@PLT
.Ltmp4:
# %bb.5:
	movq	%rax, %r13
	movq	$0, (%rax)
	cmpl	$1, %ebx
	je	.LBB0_7
# %bb.6:
	movq	%r13, %rdi
	addq	$8, %rdi
	addq	$-8, %r14
	xorl	%esi, %esi
	movq	%r14, %rdx
	callq	memset@PLT
.LBB0_7:
	movl	12(%rsp), %r14d
	testl	%r14d, %r14d
	jle	.LBB0_25
# %bb.8:
	xorl	%ebx, %ebx
	.p2align	4, 0x90
.LBB0_9:                                # =>This Inner Loop Header: Depth=1
.Ltmp5:
	movl	$32, %edi
	callq	_Znwm@PLT
.Ltmp6:
# %bb.10:                               #   in Loop: Header=BB0_9 Depth=1
	movq	%rax, (%r13,%rbx,8)
	addq	$1, %rbx
	cmpq	%rbx, %r14
	jne	.LBB0_9
# %bb.11:
	testl	%r14d, %r14d
	jle	.LBB0_25
# %bb.12:
	xorl	%ebx, %ebx
	leaq	24(%rsp), %r14
	leaq	20(%rsp), %r15
	leaq	16(%rsp), %r12
	jmp	.LBB0_13
	.p2align	4, 0x90
.LBB0_19:                               #   in Loop: Header=BB0_13 Depth=1
	movq	(%r13,%rax,8), %rax
	movq	(%r13,%rbx,8), %rcx
	movq	%rax, 16(%rcx)
	movslq	16(%rsp), %rax
	movq	(%r13,%rax,8), %rax
	movq	(%r13,%rbx,8), %rcx
	movq	%rax, 24(%rcx)
.LBB0_24:                               #   in Loop: Header=BB0_13 Depth=1
	addq	$1, %rbx
	movslq	12(%rsp), %rax
	cmpq	%rax, %rbx
	jge	.LBB0_25
.LBB0_13:                               # =>This Inner Loop Header: Depth=1
	movq	(%r13,%rbx,8), %rsi
.Ltmp8:
	movq	%r14, %rdi
	callq	_ZNSirsERi@PLT
.Ltmp9:
# %bb.14:                               #   in Loop: Header=BB0_13 Depth=1
	movq	(%r13,%rbx,8), %rsi
	addq	$4, %rsi
.Ltmp10:
	movq	%rax, %rdi
	callq	_ZNSi10_M_extractIfEERSiRT_@PLT
.Ltmp11:
# %bb.15:                               #   in Loop: Header=BB0_13 Depth=1
.Ltmp12:
	movq	%rax, %rdi
	movq	%r15, %rsi
	callq	_ZNSirsERi@PLT
.Ltmp13:
# %bb.16:                               #   in Loop: Header=BB0_13 Depth=1
.Ltmp14:
	movq	%rax, %rdi
	movq	%r12, %rsi
	callq	_ZNSirsERi@PLT
.Ltmp15:
# %bb.17:                               #   in Loop: Header=BB0_13 Depth=1
	movq	(%r13,%rbx,8), %rsi
	addq	$8, %rsi
.Ltmp16:
	movq	%rax, %rdi
	callq	_ZNSirsERi@PLT
.Ltmp17:
# %bb.18:                               #   in Loop: Header=BB0_13 Depth=1
	movl	20(%rsp), %eax
	testl	%eax, %eax
	jns	.LBB0_19
# %bb.23:                               #   in Loop: Header=BB0_13 Depth=1
	movq	(%r13,%rbx,8), %rax
	movq	$0, 24(%rax)
	movq	(%r13,%rbx,8), %rax
	movq	$0, 16(%rax)
	jmp	.LBB0_24
.LBB0_25:
	movq	(%r13), %r14
	movq	%r13, %rdi
	callq	_ZdlPv@PLT
	movq	_ZTTSt14basic_ifstreamIcSt11char_traitsIcEE@GOTPCREL(%rip), %r15
	movq	(%r15), %rax
	movq	8(%r15), %rbx
	movq	%rax, 24(%rsp)
	movq	24(%r15), %rcx
	movq	-24(%rax), %rax
	movq	%rcx, 24(%rsp,%rax)
	leaq	40(%rsp), %rdi
	callq	_ZNSt13basic_filebufIcSt11char_traitsIcEED2Ev@PLT
	movq	%rbx, 24(%rsp)
	movq	16(%r15), %rax
	movq	-24(%rbx), %rcx
	movq	%rax, 24(%rsp,%rcx)
	movq	$0, 32(%rsp)
	leaq	280(%rsp), %rdi
	callq	_ZNSt8ios_baseD2Ev@PLT
	movq	%r14, %rax
	addq	$544, %rsp                      # imm = 0x220
	.cfi_def_cfa_offset 48
	popq	%rbx
	.cfi_def_cfa_offset 40
	popq	%r12
	.cfi_def_cfa_offset 32
	popq	%r13
	.cfi_def_cfa_offset 24
	popq	%r14
	.cfi_def_cfa_offset 16
	popq	%r15
	.cfi_def_cfa_offset 8
	retq
.LBB0_2:
	.cfi_def_cfa_offset 592
.Ltmp19:
	leaq	.L.str.1(%rip), %rdi
	callq	_ZSt20__throw_length_errorPKc@PLT
.Ltmp20:
# %bb.3:
.LBB0_20:
.Ltmp2:
	movq	%rax, %r14
	jmp	.LBB0_28
.LBB0_21:
.Ltmp21:
	movq	%rax, %r14
	jmp	.LBB0_28
.LBB0_26:
.Ltmp7:
	jmp	.LBB0_27
.LBB0_22:
.Ltmp18:
.LBB0_27:
	movq	%rax, %r14
	movq	%r13, %rdi
	callq	_ZdlPv@PLT
.LBB0_28:
	leaq	24(%rsp), %rdi
	callq	_ZNSt14basic_ifstreamIcSt11char_traitsIcEED1Ev@PLT
	movq	%r14, %rdi
	callq	_Unwind_Resume@PLT
.Lfunc_end0:
	.size	_Z9load_treePKc, .Lfunc_end0-_Z9load_treePKc
	.cfi_endproc
	.section	.gcc_except_table,"a",@progbits
	.p2align	2
GCC_except_table0:
.Lexception0:
	.byte	255                             # @LPStart Encoding = omit
	.byte	255                             # @TType Encoding = omit
	.byte	1                               # Call site Encoding = uleb128
	.uleb128 .Lcst_end0-.Lcst_begin0
.Lcst_begin0:
	.uleb128 .Lfunc_begin0-.Lfunc_begin0    # >> Call Site 1 <<
	.uleb128 .Ltmp0-.Lfunc_begin0           #   Call between .Lfunc_begin0 and .Ltmp0
	.byte	0                               #     has no landing pad
	.byte	0                               #   On action: cleanup
	.uleb128 .Ltmp0-.Lfunc_begin0           # >> Call Site 2 <<
	.uleb128 .Ltmp1-.Ltmp0                  #   Call between .Ltmp0 and .Ltmp1
	.uleb128 .Ltmp2-.Lfunc_begin0           #     jumps to .Ltmp2
	.byte	0                               #   On action: cleanup
	.uleb128 .Ltmp3-.Lfunc_begin0           # >> Call Site 3 <<
	.uleb128 .Ltmp4-.Ltmp3                  #   Call between .Ltmp3 and .Ltmp4
	.uleb128 .Ltmp21-.Lfunc_begin0          #     jumps to .Ltmp21
	.byte	0                               #   On action: cleanup
	.uleb128 .Ltmp4-.Lfunc_begin0           # >> Call Site 4 <<
	.uleb128 .Ltmp5-.Ltmp4                  #   Call between .Ltmp4 and .Ltmp5
	.byte	0                               #     has no landing pad
	.byte	0                               #   On action: cleanup
	.uleb128 .Ltmp5-.Lfunc_begin0           # >> Call Site 5 <<
	.uleb128 .Ltmp6-.Ltmp5                  #   Call between .Ltmp5 and .Ltmp6
	.uleb128 .Ltmp7-.Lfunc_begin0           #     jumps to .Ltmp7
	.byte	0                               #   On action: cleanup
	.uleb128 .Ltmp8-.Lfunc_begin0           # >> Call Site 6 <<
	.uleb128 .Ltmp17-.Ltmp8                 #   Call between .Ltmp8 and .Ltmp17
	.uleb128 .Ltmp18-.Lfunc_begin0          #     jumps to .Ltmp18
	.byte	0                               #   On action: cleanup
	.uleb128 .Ltmp19-.Lfunc_begin0          # >> Call Site 7 <<
	.uleb128 .Ltmp20-.Ltmp19                #   Call between .Ltmp19 and .Ltmp20
	.uleb128 .Ltmp21-.Lfunc_begin0          #     jumps to .Ltmp21
	.byte	0                               #   On action: cleanup
	.uleb128 .Ltmp20-.Lfunc_begin0          # >> Call Site 8 <<
	.uleb128 .Lfunc_end0-.Ltmp20            #   Call between .Ltmp20 and .Lfunc_end0
	.byte	0                               #     has no landing pad
	.byte	0                               #   On action: cleanup
.Lcst_end0:
	.p2align	2
                                        # -- End function
	.text
	.globl	_Z7predictP4NodePKf             # -- Begin function _Z7predictP4NodePKf
	.p2align	4, 0x90
	.type	_Z7predictP4NodePKf,@function
_Z7predictP4NodePKf:                    # @_Z7predictP4NodePKf
	.cfi_startproc
# %bb.0:
	movq	16(%rdi), %rax
	jmp	.LBB1_1
	.p2align	4, 0x90
.LBB1_4:                                #   in Loop: Header=BB1_1 Depth=1
	movq	%rax, %rdi
	movq	16(%rax), %rax
.LBB1_1:                                # =>This Inner Loop Header: Depth=1
	testq	%rax, %rax
	je	.LBB1_5
# %bb.2:                                #   in Loop: Header=BB1_1 Depth=1
	movslq	(%rdi), %rcx
	movss	4(%rdi), %xmm0                  # xmm0 = mem[0],zero,zero,zero
	ucomiss	(%rsi,%rcx,4), %xmm0
	ja	.LBB1_4
# %bb.3:                                #   in Loop: Header=BB1_1 Depth=1
	movq	24(%rdi), %rax
	jmp	.LBB1_4
.LBB1_5:
	movl	8(%rdi), %eax
	retq
.Lfunc_end1:
	.size	_Z7predictP4NodePKf, .Lfunc_end1-_Z7predictP4NodePKf
	.cfi_endproc
                                        # -- End function
	.section	.rodata.cst4,"aM",@progbits,4
	.p2align	2                               # -- Begin function main
.LCPI2_0:
	.long	0x4f800000                      # float 4.2949673E+9
.LCPI2_1:
	.long	0x40000000                      # float 2
.LCPI2_2:
	.long	0x5f000000                      # float 9.22337203E+18
.LCPI2_3:
	.long	0x3f800000                      # float 1
	.text
	.globl	main
	.p2align	4, 0x90
	.type	main,@function
main:                                   # @main
.Lfunc_begin1:
	.cfi_startproc
	.cfi_personality 155, DW.ref.__gxx_personality_v0
	.cfi_lsda 27, .Lexception1
# %bb.0:
	pushq	%rbp
	.cfi_def_cfa_offset 16
	pushq	%r15
	.cfi_def_cfa_offset 24
	pushq	%r14
	.cfi_def_cfa_offset 32
	pushq	%r13
	.cfi_def_cfa_offset 40
	pushq	%r12
	.cfi_def_cfa_offset 48
	pushq	%rbx
	.cfi_def_cfa_offset 56
	subq	$5064, %rsp                     # imm = 0x13C8
	.cfi_def_cfa_offset 5120
	.cfi_offset %rbx, -56
	.cfi_offset %r12, -48
	.cfi_offset %r13, -40
	.cfi_offset %r14, -32
	.cfi_offset %r15, -24
	.cfi_offset %rbp, -16
	leaq	.L.str(%rip), %rdi
	callq	_Z9load_treePKc
	movq	%rax, %r15
	movl	$1280000000, %edi               # imm = 0x4C4B4000
	callq	_Znwm@PLT
	leaq	1280000000(%rax), %r13
	xorl	%r14d, %r14d
	movl	$1280000000, %edx               # imm = 0x4C4B4000
	movq	%rax, 32(%rsp)                  # 8-byte Spill
	movq	%rax, %rdi
	xorl	%esi, %esi
	callq	memset@PLT
	movq	$1, 64(%rsp)
	movl	$1, %edi
	movl	$16, %esi
	movl	$2, %ebx
	movabsq	$945986875574848801, %r8        # imm = 0xD20D20D20D20D21
	movl	$1, %ebp
	.p2align	4, 0x90
.LBB2_1:                                # =>This Inner Loop Header: Depth=1
	movq	%rbx, %rax
	shrq	$4, %rax
	mulq	%r8
	movq	%rdx, %rcx
	movq	%r14, %rax
	shrq	$4, %rax
	mulq	%r8
	shrq	%rdx
	imull	$624, %edx, %eax                # imm = 0x270
	movl	%ebp, %edx
	subl	%eax, %edx
	movq	%rdi, %rax
	shrq	$30, %rax
	xorl	%edi, %eax
	imull	$1812433253, %eax, %eax         # imm = 0x6C078965
	addl	%edx, %eax
	movq	%rax, 56(%rsp,%rsi)
	cmpq	$4992, %rsi                     # imm = 0x1380
	je	.LBB2_3
# %bb.2:                                #   in Loop: Header=BB2_1 Depth=1
	shrq	%rcx
	imulq	$624, %rcx, %rcx                # imm = 0x270
	movq	%rbx, %rdi
	subq	%rcx, %rdi
	movq	%rax, %rcx
	shrq	$30, %rcx
	xorl	%eax, %ecx
	imull	$1812433253, %ecx, %eax         # imm = 0x6C078965
	addl	%eax, %edi
	movq	%rdi, 64(%rsp,%rsi)
	addq	$2, %rbp
	addq	$16, %rsi
	addq	$2, %rbx
	addq	$2, %r14
	jmp	.LBB2_1
.LBB2_3:
	movq	$624, 5056(%rsp)                # imm = 0x270
	movl	$1, %ebp
	leaq	64(%rsp), %r12
	movq	32(%rsp), %r14                  # 8-byte Reload
	.p2align	4, 0x90
.LBB2_4:                                # =>This Loop Header: Depth=1
                                        #     Child Loop BB2_8 Depth 2
	flds	.LCPI2_0(%rip)
	fstpt	(%rsp)
	callq	logl@PLT
	fstpt	44(%rsp)                        # 10-byte Folded Spill
	flds	.LCPI2_1(%rip)
	fstpt	(%rsp)
	callq	logl@PLT
	fldt	44(%rsp)                        # 10-byte Folded Reload
	fdivp	%st, %st(1)
	flds	.LCPI2_2(%rip)
	xorl	%ecx, %ecx
	fxch	%st(1)
	fucomi	%st(1), %st
	fldz
	fcmovnb	%st(2), %st
	fstp	%st(2)
	fsubp	%st, %st(1)
	setae	%cl
	fnstcw	22(%rsp)
	movzwl	22(%rsp), %eax
	orl	$3072, %eax                     # imm = 0xC00
	movw	%ax, 30(%rsp)
	fldcw	30(%rsp)
	fistpll	56(%rsp)
	fldcw	22(%rsp)
	shlq	$63, %rcx
	xorq	56(%rsp), %rcx
	leaq	9(%rcx), %rax
	movq	%rax, %rdx
	orq	%rcx, %rdx
	shrq	$32, %rdx
	je	.LBB2_5
# %bb.6:                                #   in Loop: Header=BB2_4 Depth=1
	xorl	%edx, %edx
	divq	%rcx
	movq	%rax, %rbx
	jmp	.LBB2_7
	.p2align	4, 0x90
.LBB2_5:                                #   in Loop: Header=BB2_4 Depth=1
                                        # kill: def $eax killed $eax killed $rax
	xorl	%edx, %edx
	divl	%ecx
	movl	%eax, %ebx
.LBB2_7:                                #   in Loop: Header=BB2_4 Depth=1
	testq	%rbx, %rbx
	cmoveq	%rbp, %rbx
	xorps	%xmm0, %xmm0
	movss	%xmm0, 44(%rsp)                 # 4-byte Spill
	movss	.LCPI2_3(%rip), %xmm0           # xmm0 = mem[0],zero,zero,zero
	movss	%xmm0, 24(%rsp)                 # 4-byte Spill
	jmp	.LBB2_8
	.p2align	4, 0x90
.LBB2_11:                               #   in Loop: Header=BB2_8 Depth=2
	xorps	%xmm0, %xmm0
	cvtsi2ss	%rax, %xmm0
.LBB2_12:                               #   in Loop: Header=BB2_8 Depth=2
	movss	24(%rsp), %xmm2                 # 4-byte Reload
                                        # xmm2 = mem[0],zero,zero,zero
	mulss	%xmm2, %xmm0
	movss	44(%rsp), %xmm1                 # 4-byte Reload
                                        # xmm1 = mem[0],zero,zero,zero
	addss	%xmm0, %xmm1
	movss	%xmm1, 44(%rsp)                 # 4-byte Spill
	mulss	.LCPI2_0(%rip), %xmm2
	movss	%xmm2, 24(%rsp)                 # 4-byte Spill
	addq	$-1, %rbx
	je	.LBB2_13
.LBB2_8:                                #   Parent Loop BB2_4 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
.Ltmp22:
	movq	%r12, %rdi
	callq	_ZNSt23mersenne_twister_engineImLm32ELm624ELm397ELm31ELm2567483615ELm11ELm4294967295ELm7ELm2636928640ELm15ELm4022730752ELm18ELm1812433253EEclEv
.Ltmp23:
# %bb.9:                                #   in Loop: Header=BB2_8 Depth=2
	testq	%rax, %rax
	jns	.LBB2_11
# %bb.10:                               #   in Loop: Header=BB2_8 Depth=2
	movq	%rax, %rcx
	shrq	%rcx
	andl	$1, %eax
	orq	%rcx, %rax
	xorps	%xmm0, %xmm0
	cvtsi2ss	%rax, %xmm0
	addss	%xmm0, %xmm0
	jmp	.LBB2_12
	.p2align	4, 0x90
.LBB2_13:                               #   in Loop: Header=BB2_4 Depth=1
	movss	44(%rsp), %xmm0                 # 4-byte Reload
                                        # xmm0 = mem[0],zero,zero,zero
	divss	24(%rsp), %xmm0                 # 4-byte Folded Reload
	ucomiss	.LCPI2_3(%rip), %xmm0
	jae	.LBB2_14
.LBB2_15:                               #   in Loop: Header=BB2_4 Depth=1
	movss	%xmm0, (%r14)
	addq	$4, %r14
	cmpq	%r13, %r14
	jne	.LBB2_4
	jmp	.LBB2_16
.LBB2_14:                               #   in Loop: Header=BB2_4 Depth=1
	xorps	%xmm1, %xmm1
	movss	.LCPI2_3(%rip), %xmm0           # xmm0 = mem[0],zero,zero,zero
	callq	nextafterf@PLT
	jmp	.LBB2_15
.LBB2_16:
	movq	16(%r15), %rbp
	xorl	%ecx, %ecx
	xorl	%esi, %esi
	jmp	.LBB2_17
	.p2align	4, 0x90
.LBB2_22:                               #   in Loop: Header=BB2_17 Depth=1
	addl	8(%rdi), %esi
	addq	$1, %rcx
	cmpq	$10000000, %rcx                 # imm = 0x989680
	je	.LBB2_23
.LBB2_17:                               # =>This Loop Header: Depth=1
                                        #     Child Loop BB2_19 Depth 2
	movq	%r15, %rdi
	testq	%rbp, %rbp
	je	.LBB2_22
# %bb.18:                               #   in Loop: Header=BB2_17 Depth=1
	movq	%rcx, %rdx
	shlq	$7, %rdx
	addq	32(%rsp), %rdx                  # 8-byte Folded Reload
	movq	%rbp, %rax
	movq	%r15, %rdi
	jmp	.LBB2_19
	.p2align	4, 0x90
.LBB2_21:                               #   in Loop: Header=BB2_19 Depth=2
	movq	%rax, %rdi
	movq	16(%rax), %rax
	testq	%rax, %rax
	je	.LBB2_22
.LBB2_19:                               #   Parent Loop BB2_17 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	movslq	(%rdi), %rbx
	movss	4(%rdi), %xmm0                  # xmm0 = mem[0],zero,zero,zero
	ucomiss	(%rdx,%rbx,4), %xmm0
	ja	.LBB2_21
# %bb.20:                               #   in Loop: Header=BB2_19 Depth=2
	movq	24(%rdi), %rax
	jmp	.LBB2_21
.LBB2_23:
.Ltmp25:
	movq	_ZSt4cout@GOTPCREL(%rip), %rdi
	callq	_ZNSolsEi@PLT
.Ltmp26:
# %bb.24:
	movb	$10, 21(%rsp)
.Ltmp27:
	leaq	21(%rsp), %rsi
	movl	$1, %edx
	movq	%rax, %rdi
	callq	_ZSt16__ostream_insertIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_PKS3_l@PLT
.Ltmp28:
# %bb.25:
	movq	32(%rsp), %rdi                  # 8-byte Reload
	callq	_ZdlPv@PLT
	xorl	%eax, %eax
	addq	$5064, %rsp                     # imm = 0x13C8
	.cfi_def_cfa_offset 56
	popq	%rbx
	.cfi_def_cfa_offset 48
	popq	%r12
	.cfi_def_cfa_offset 40
	popq	%r13
	.cfi_def_cfa_offset 32
	popq	%r14
	.cfi_def_cfa_offset 24
	popq	%r15
	.cfi_def_cfa_offset 16
	popq	%rbp
	.cfi_def_cfa_offset 8
	retq
.LBB2_26:
	.cfi_def_cfa_offset 5120
.Ltmp29:
	jmp	.LBB2_27
.LBB2_28:
.Ltmp24:
.LBB2_27:
	movq	%rax, %rbx
	movq	32(%rsp), %rdi                  # 8-byte Reload
	callq	_ZdlPv@PLT
	movq	%rbx, %rdi
	callq	_Unwind_Resume@PLT
.Lfunc_end2:
	.size	main, .Lfunc_end2-main
	.cfi_endproc
	.section	.gcc_except_table,"a",@progbits
	.p2align	2
GCC_except_table2:
.Lexception1:
	.byte	255                             # @LPStart Encoding = omit
	.byte	255                             # @TType Encoding = omit
	.byte	1                               # Call site Encoding = uleb128
	.uleb128 .Lcst_end1-.Lcst_begin1
.Lcst_begin1:
	.uleb128 .Lfunc_begin1-.Lfunc_begin1    # >> Call Site 1 <<
	.uleb128 .Ltmp22-.Lfunc_begin1          #   Call between .Lfunc_begin1 and .Ltmp22
	.byte	0                               #     has no landing pad
	.byte	0                               #   On action: cleanup
	.uleb128 .Ltmp22-.Lfunc_begin1          # >> Call Site 2 <<
	.uleb128 .Ltmp23-.Ltmp22                #   Call between .Ltmp22 and .Ltmp23
	.uleb128 .Ltmp24-.Lfunc_begin1          #     jumps to .Ltmp24
	.byte	0                               #   On action: cleanup
	.uleb128 .Ltmp25-.Lfunc_begin1          # >> Call Site 3 <<
	.uleb128 .Ltmp28-.Ltmp25                #   Call between .Ltmp25 and .Ltmp28
	.uleb128 .Ltmp29-.Lfunc_begin1          #     jumps to .Ltmp29
	.byte	0                               #   On action: cleanup
	.uleb128 .Ltmp28-.Lfunc_begin1          # >> Call Site 4 <<
	.uleb128 .Lfunc_end2-.Ltmp28            #   Call between .Ltmp28 and .Lfunc_end2
	.byte	0                               #     has no landing pad
	.byte	0                               #   On action: cleanup
.Lcst_end1:
	.p2align	2
                                        # -- End function
	.section	.rodata.cst16,"aM",@progbits,16
	.p2align	4                               # -- Begin function _ZNSt23mersenne_twister_engineImLm32ELm624ELm397ELm31ELm2567483615ELm11ELm4294967295ELm7ELm2636928640ELm15ELm4022730752ELm18ELm1812433253EEclEv
.LCPI3_0:
	.quad	-2147483648                     # 0xffffffff80000000
	.quad	-2147483648                     # 0xffffffff80000000
.LCPI3_1:
	.quad	2147483646                      # 0x7ffffffe
	.quad	2147483646                      # 0x7ffffffe
.LCPI3_2:
	.quad	2567483615                      # 0x9908b0df
	.quad	2567483615                      # 0x9908b0df
	.section	.text._ZNSt23mersenne_twister_engineImLm32ELm624ELm397ELm31ELm2567483615ELm11ELm4294967295ELm7ELm2636928640ELm15ELm4022730752ELm18ELm1812433253EEclEv,"axG",@progbits,_ZNSt23mersenne_twister_engineImLm32ELm624ELm397ELm31ELm2567483615ELm11ELm4294967295ELm7ELm2636928640ELm15ELm4022730752ELm18ELm1812433253EEclEv,comdat
	.weak	_ZNSt23mersenne_twister_engineImLm32ELm624ELm397ELm31ELm2567483615ELm11ELm4294967295ELm7ELm2636928640ELm15ELm4022730752ELm18ELm1812433253EEclEv
	.p2align	4, 0x90
	.type	_ZNSt23mersenne_twister_engineImLm32ELm624ELm397ELm31ELm2567483615ELm11ELm4294967295ELm7ELm2636928640ELm15ELm4022730752ELm18ELm1812433253EEclEv,@function
_ZNSt23mersenne_twister_engineImLm32ELm624ELm397ELm31ELm2567483615ELm11ELm4294967295ELm7ELm2636928640ELm15ELm4022730752ELm18ELm1812433253EEclEv: # @_ZNSt23mersenne_twister_engineImLm32ELm624ELm397ELm31ELm2567483615ELm11ELm4294967295ELm7ELm2636928640ELm15ELm4022730752ELm18ELm1812433253EEclEv
	.cfi_startproc
# %bb.0:
	movq	4992(%rdi), %rax
	cmpq	$624, %rax                      # imm = 0x270
	jb	.LBB3_6
# %bb.1:
	movq	(%rdi), %xmm0                   # xmm0 = mem[0],zero
	pshufd	$68, %xmm0, %xmm3               # xmm3 = xmm0[0,1,0,1]
	xorl	%eax, %eax
	movaps	.LCPI3_0(%rip), %xmm0           # xmm0 = [18446744071562067968,18446744071562067968]
	movaps	.LCPI3_1(%rip), %xmm1           # xmm1 = [2147483646,2147483646]
	movdqa	.LCPI3_2(%rip), %xmm2           # xmm2 = [2567483615,2567483615]
	.p2align	4, 0x90
.LBB3_2:                                # =>This Inner Loop Header: Depth=1
	movdqa	%xmm3, %xmm4
	movups	8(%rdi,%rax,8), %xmm3
	shufps	$78, %xmm3, %xmm4               # xmm4 = xmm4[2,3],xmm3[0,1]
	andps	%xmm0, %xmm4
	movaps	%xmm3, %xmm5
	andps	%xmm1, %xmm5
	orps	%xmm4, %xmm5
	movdqu	3176(%rdi,%rax,8), %xmm4
	psrlq	$1, %xmm5
	pxor	%xmm4, %xmm5
	movaps	%xmm3, %xmm4
	psllq	$63, %xmm4
	psrad	$31, %xmm4
	pshufd	$245, %xmm4, %xmm4              # xmm4 = xmm4[1,1,3,3]
	pand	%xmm2, %xmm4
	pxor	%xmm5, %xmm4
	movdqu	%xmm4, (%rdi,%rax,8)
	addq	$2, %rax
	cmpq	$226, %rax
	jne	.LBB3_2
# %bb.3:
	pshufd	$238, %xmm3, %xmm3              # xmm3 = xmm3[2,3,2,3]
	movq	%xmm3, %rax
	andq	$-2147483648, %rax              # imm = 0x80000000
	movq	1816(%rdi), %rcx
	movl	%ecx, %edx
	movq	%rcx, %xmm3
                                        # kill: def $ecx killed $ecx killed $rcx def $rcx
	andl	$2147483646, %ecx               # imm = 0x7FFFFFFE
	orq	%rax, %rcx
	shrq	%rcx
	xorq	4984(%rdi), %rcx
	movl	$2567483615, %eax               # imm = 0x9908B0DF
	andl	$1, %edx
	negl	%edx
	andl	$-1727483681, %edx              # imm = 0x9908B0DF
	xorq	%rcx, %rdx
	movq	%rdx, 1808(%rdi)
	pshufd	$68, %xmm3, %xmm3               # xmm3 = xmm3[0,1,0,1]
	xorl	%ecx, %ecx
	.p2align	4, 0x90
.LBB3_4:                                # =>This Inner Loop Header: Depth=1
	movups	1824(%rdi,%rcx,8), %xmm4
	shufps	$78, %xmm4, %xmm3               # xmm3 = xmm3[2,3],xmm4[0,1]
	andps	%xmm0, %xmm3
	movaps	%xmm4, %xmm5
	andps	%xmm1, %xmm5
	orps	%xmm3, %xmm5
	movdqu	(%rdi,%rcx,8), %xmm3
	psrlq	$1, %xmm5
	pxor	%xmm3, %xmm5
	movaps	%xmm4, %xmm3
	psllq	$63, %xmm4
	psrad	$31, %xmm4
	pshufd	$245, %xmm4, %xmm4              # xmm4 = xmm4[1,1,3,3]
	pand	%xmm2, %xmm4
	pxor	%xmm5, %xmm4
	movdqu	%xmm4, 1816(%rdi,%rcx,8)
	addq	$2, %rcx
	cmpq	$396, %rcx                      # imm = 0x18C
	jne	.LBB3_4
# %bb.5:
	movq	$-2147483648, %rcx              # imm = 0x80000000
	andq	4984(%rdi), %rcx
	movq	(%rdi), %rdx
	movl	%edx, %esi
	andl	$2147483646, %esi               # imm = 0x7FFFFFFE
	orq	%rcx, %rsi
	shrq	%rsi
	xorq	3168(%rdi), %rsi
	andl	$1, %edx
	negl	%edx
	andl	%edx, %eax
	xorq	%rsi, %rax
	movq	%rax, 4984(%rdi)
	xorl	%eax, %eax
.LBB3_6:
	leaq	1(%rax), %rcx
	movq	%rcx, 4992(%rdi)
	movq	(%rdi,%rax,8), %rax
	movq	%rax, %rcx
	shrq	$11, %rcx
	movl	%ecx, %ecx
	xorq	%rax, %rcx
	movl	%ecx, %eax
	andl	$20601005, %eax                 # imm = 0x13A58AD
	shlq	$7, %rax
	xorq	%rcx, %rax
	movl	%eax, %ecx
	andl	$122764, %ecx                   # imm = 0x1DF8C
	shlq	$15, %rcx
	xorq	%rax, %rcx
	movq	%rcx, %rax
	shrq	$18, %rax
	xorq	%rcx, %rax
	retq
.Lfunc_end3:
	.size	_ZNSt23mersenne_twister_engineImLm32ELm624ELm397ELm31ELm2567483615ELm11ELm4294967295ELm7ELm2636928640ELm15ELm4022730752ELm18ELm1812433253EEclEv, .Lfunc_end3-_ZNSt23mersenne_twister_engineImLm32ELm624ELm397ELm31ELm2567483615ELm11ELm4294967295ELm7ELm2636928640ELm15ELm4022730752ELm18ELm1812433253EEclEv
	.cfi_endproc
                                        # -- End function
	.section	.text.startup,"ax",@progbits
	.p2align	4, 0x90                         # -- Begin function _GLOBAL__sub_I_basic.cpp
	.type	_GLOBAL__sub_I_basic.cpp,@function
_GLOBAL__sub_I_basic.cpp:               # @_GLOBAL__sub_I_basic.cpp
	.cfi_startproc
# %bb.0:
	pushq	%rbx
	.cfi_def_cfa_offset 16
	.cfi_offset %rbx, -16
	leaq	_ZStL8__ioinit(%rip), %rbx
	movq	%rbx, %rdi
	callq	_ZNSt8ios_base4InitC1Ev@PLT
	movq	_ZNSt8ios_base4InitD1Ev@GOTPCREL(%rip), %rdi
	leaq	__dso_handle(%rip), %rdx
	movq	%rbx, %rsi
	popq	%rbx
	.cfi_def_cfa_offset 8
	jmp	__cxa_atexit@PLT                # TAILCALL
.Lfunc_end4:
	.size	_GLOBAL__sub_I_basic.cpp, .Lfunc_end4-_GLOBAL__sub_I_basic.cpp
	.cfi_endproc
                                        # -- End function
	.type	_ZStL8__ioinit,@object          # @_ZStL8__ioinit
	.local	_ZStL8__ioinit
	.comm	_ZStL8__ioinit,1,1
	.hidden	__dso_handle
	.type	.L.str,@object                  # @.str
	.section	.rodata.str1.1,"aMS",@progbits,1
.L.str:
	.asciz	"tree.txt"
	.size	.L.str, 9

	.type	.L.str.1,@object                # @.str.1
.L.str.1:
	.asciz	"cannot create std::vector larger than max_size()"
	.size	.L.str.1, 49

	.section	.init_array,"aw",@init_array
	.p2align	3
	.quad	_GLOBAL__sub_I_basic.cpp
	.hidden	DW.ref.__gxx_personality_v0
	.weak	DW.ref.__gxx_personality_v0
	.section	.data.DW.ref.__gxx_personality_v0,"aGw",@progbits,DW.ref.__gxx_personality_v0,comdat
	.p2align	3
	.type	DW.ref.__gxx_personality_v0,@object
	.size	DW.ref.__gxx_personality_v0, 8
DW.ref.__gxx_personality_v0:
	.quad	__gxx_personality_v0
	.ident	"Ubuntu clang version 14.0.0-1ubuntu1.1"
	.section	".note.GNU-stack","",@progbits
	.addrsig
	.addrsig_sym __gxx_personality_v0
	.addrsig_sym _GLOBAL__sub_I_basic.cpp
	.addrsig_sym _Unwind_Resume
	.addrsig_sym _ZStL8__ioinit
	.addrsig_sym __dso_handle
	.addrsig_sym _ZSt4cout
