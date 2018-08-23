module Parquet_kernel
  !
  ! Purpose
  ! ========
  !   determine the reducible vertex function in particle-hole and particle-particle channels
  ! 
  use mpi_mod
  use global_parameter
  use math_mod
  use parquet_util
  use cudafor
  use cublas

contains
  !------------------------------------
  attributes(global) subroutine reduc_kernel0(idx, ComIdx1, ComIdx2, Nf, One, xi, Pi, beta, Two, mu, Ek, dummy, G1, Gkw, Fermionic, dummy3D_1, dummy3D_2, F_d, F_m, Nc, xU, Index_fermionic, Index_bosonic, Nt, k, Nx, Ny)
    integer, value :: idx, Nf, Nc, Fermionic, Nt, k, Nx, Ny
    real(dp), value :: One, Pi, beta, mu, Two, xU
    complex(dp), value :: xi
    real(dp) :: Ek(:, :)
    complex(dp) :: dummy, G1(:), Gkw(:), F_d(:, :, :), F_m(:, :, :), dummy3D_1(:, :), dummy3D_2(:, :)
    type(Indxmap) :: ComIdx1, ComIdx2,  Index_fermionic(:), Index_bosonic(:)
    
    integer :: i, j
    i = (blockIdx%x-1)*blockDim%x + threadIdx%x
    if (i > Nt) then
      return
    end if

    call index_operation_FaddB(Index_fermionic(i), Index_bosonic(idx), ComIdx1, Nx, Ny)
    if (ComIdx1%iw > Nf .or. ComIdx1%iw < 1) then
      ! use the non-interacting Green's function when k+q is outside of the box
      dummy = One/(xi*Pi/beta*(Two*(ComIdx1%iw-Nf/2-1) + One) + mu - Ek(ComIdx1%ix, ComIdx1%iy))
    else
      dummy = Gkw(list_index_Fe(ComIdx1, Ny, Nf))
    end if
    do j = 1, Nt
      dummy3D_1(i, j) = F_d(i, j, k)*Gkw(i)*dummy/beta/Nc
      dummy3D_2(i, j) = F_m(i, j, k)*Gkw(i)*dummy/beta/Nc
    end do
    G1(i) = xU*Gkw(i)*dummy*xU/beta/Nc

  end subroutine reduc_kernel0

  !------------------------------------
  attributes(global) subroutine reduc_kernel1(idx, ComIdx1, ComIdx2, Nf, One, xi, Pi, beta, Two, mu, Ek, dummy, G1, Gkw, Fermionic, dummy3D_1, dummy3D_2, F_d, F_m, Nc, xU, Index_fermionic, Index_bosonic, Nt, k, Nx, Ny)
    integer, value :: idx, Nf, Nc, Fermionic, Nt, k, Nx, Ny
    real(dp), value :: One, Pi, beta, mu, Two, xU
    complex(dp), value :: xi
    real(dp) :: Ek(:, :)
    complex(dp) :: dummy, G1(:), Gkw(:), F_d(:, :, :), F_m(:, :, :), dummy3D_1(:, :), dummy3D_2(:, :)
    type(Indxmap) :: ComIdx1, ComIdx2, Index_fermionic(:), Index_bosonic(:)

    integer :: i, j
    i = (blockIdx%x-1)*blockDim%x + threadIdx%x

    if (i > Nt) then
      return
    end if

    call index_operation_FaddB(Index_fermionic(i), Index_bosonic(idx), ComIdx1, Nx, Ny)
    if (ComIdx1%iw > Nf .or. ComIdx1%iw < 1) then
      ! use the non-interacting Green's function when k+q is outside of the box
      dummy = One/(xi*Pi/beta*(Two*(ComIdx1%iw-Nf/2-1) + One) + mu - Ek(ComIdx1%ix, ComIdx1%iy))
    else
      dummy = Gkw(list_index_Fe(ComIdx1, Ny, Nf))
    end if
    do j = 1, Nt
      dummy3D_1(j, i) = F_d(j, i, k)*Gkw(i)*dummy/beta/Nc
      dummy3D_2(j, i) = F_m(j, i, k)*Gkw(i)*dummy/beta/Nc
    end do

  end subroutine reduc_kernel1

  !------------------------------------
  attributes(global) subroutine reduc_kernel2_0(G_d, G_m, k, idx, One, f_damping, xU, Chi0_ph, dummy3D_3, dummy3D_4, G1, Nt)
    integer, value :: k, idx, Nt
    real(dp), value :: One, xU, f_damping
    complex(dp), value :: G1
    complex(dp) :: chi0_ph(:), G_d(:, :, :), G_m(:, :, :), dummy3D_3(:, :), dummy3D_4(:, :)

    integer :: i,j
    i = (blockIdx%x-1)*blockDim%x + threadIdx%x
    j = (blockIdx%y-1)*blockDim%y + threadIdx%y

    if (i > Nt .OR. j > Nt) then
      return
    end if

    G_d(i, j, k) = (One-f_damping)*(xU*Chi0_ph(idx)*xU) + f_damping*(dummy3D_3(i, j) - G1 + xU*Chi0_ph(idx)*xU)
    G_m(i, j, k) = (One-f_damping)*(xU*Chi0_ph(idx)*xU) + f_damping*(dummy3D_4(i, j) - G1 + xU*Chi0_ph(idx)*xU)
  
  end subroutine reduc_kernel2_0

  !------------------------------------
  attributes(global) subroutine reduc_kernel2_1(G_d, G_m, k, idx, One, f_damping, xU, Chi0_ph, dummy3D_3, dummy3D_4, G1, F_d, F_m, Nt)
    integer, value :: k, idx, Nt
    real(dp), value :: One, xU, f_damping
    complex(dp), value :: G1
    complex(dp) :: chi0_ph(:), G_d(:, :, :), G_m(:, :, :), dummy3D_3(:, :), dummy3D_4(:, :), F_d(:, :, :), F_m(:, :, :)

    integer :: i,j
    i = (blockIdx%x-1)*blockDim%x + threadIdx%x
    j = (blockIdx%y-1)*blockDim%y + threadIdx%y

    if (i > Nt .OR. j > Nt) then
      return
    end if

    G_d(i, j, k) = (One-f_damping)*(F_d(i, j, k)-G_d(i, j, k)) + f_damping*(dummy3D_3(i, j) - G1 + xU*Chi0_ph(idx)*xU)
    G_m(i, j, k) = (One-f_damping)*(F_m(i, j, k)-G_m(i, j, k)) + f_damping*(dummy3D_4(i, j) - G1 + xU*Chi0_ph(idx)*xU)

  end subroutine reduc_kernel2_1

  !------------------------------------
  attributes(global) subroutine reduc_kernel3(idx, ComIdx1, ComIdx2, Nf, One, xi, Pi, beta, Two, mu, Ek, dummy, G1, Gkw, Fermionic, dummy3D_1, dummy3D_2, F_d, F_m, Nc, xU, Index_fermionic, Index_bosonic, Nt, k, Half, F_s, F_t, Nx, Ny)
    integer, value :: idx, Nf, Nc, Fermionic, Nt, k, Nx, Ny
    real(dp), value :: One, Pi, beta, mu, Two, xU, Half
    complex(dp), value :: xi
    real(dp) :: Ek(:, :)
    complex(dp) :: dummy, G1(:), Gkw(:), F_d(:, :, :), F_m(:, :, :), dummy3D_1(:, :), dummy3D_2(:, :), F_s(:, :, :), F_t(:, :, :)
    type(Indxmap) :: ComIdx1, ComIdx2, Index_fermionic(:), Index_bosonic(:)
    
    integer :: i, j
    i = (blockIdx%x-1)*blockDim%x + threadIdx%x

    if (i > Nt) then
      return
    end if

    call index_operation_MinusF(Index_fermionic(i), Index_fermionic(i), ComIdx1, Nx, Ny, Nf)
    call index_operation_FaddB(ComIdx1, Index_bosonic(idx), ComIdx2, Nx, Ny)

    if (ComIdx2%iw > Nf .or. ComIdx2%iw < 1) then
      ! use the non-interacting green's function when q-k is outside the box
      dummy = One/( xi*Pi/beta*(Two*(ComIdx2%iw-Nf/2-1) + One) + mu - Ek(ComIdx2%ix, ComIdx2%iy) )
    else
      dummy = Gkw(list_index_Fe(ComIdx2, Ny, Nf))
    end if
    do j = 1, Nt
      dummy3D_1(i, j) = -Half*F_s(i, j, k)*Gkw(i)*dummy/beta/Nc
      dummy3D_2(i, j) =  Half*F_t(i, j, k)*Gkw(i)*dummy/beta/Nc
    end do
    G1(i) = -xU*Gkw(i)*dummy*(Two*xU)/beta/Nc

  end subroutine reduc_kernel3

  !------------------------------------
  attributes(global) subroutine reduc_kernel4(idx, ComIdx1, ComIdx2, Nf, One, xi, Pi, beta, Two, mu, Ek, dummy, G1, Gkw, Fermionic, dummy3D_1, dummy3D_2, F_d, F_m, Nc, xU, Index_fermionic, Index_bosonic, Nt, k, Half, F_s, F_t, Nx, Ny)
    integer, value :: idx, Nf, Nc, Fermionic, Nt, k, Nx, Ny
    real(dp), value :: One, Pi, beta, mu, Two, xU, Half
    complex(dp), value :: xi
    real(dp) :: Ek(:, :)
    complex(dp) :: dummy, G1(:), Gkw(:), F_d(:, :, :), F_m(:, :, :), dummy3D_1(:, :), dummy3D_2(:, :), F_s(:, :, :), F_t(:, :, :)
    type(Indxmap) :: ComIdx1, ComIdx2, Index_fermionic(:), Index_bosonic(:)

    integer :: i, j
    i = (blockIdx%x-1)*blockDim%x + threadIdx%x
    if (i>Nt) then
      return
    end if

    call index_operation_MinusF(Index_fermionic(i), Index_fermionic(i), ComIdx1, Nx, Ny, Nf)
    call index_operation_FaddB(ComIdx1, Index_bosonic(idx), ComIdx2, Nx, Ny)
    if (ComIdx2%iw > Nf .or. ComIdx2%iw < 1) then
      ! use the non-interacting green's function when q-k is outside the box
      dummy = One/( xi*Pi/beta*(Two*(ComIdx2%iw-Nf/2-1) + One) + mu - Ek(ComIdx2%ix, ComIdx2%iy) )
    else
      dummy = Gkw(list_index_Fe(ComIdx2, Ny, Nf))
    end if
    do j = 1, Nt
      dummy3D_1(j, i) = -Half*F_s(j, i, k)*Gkw(i)*dummy/beta/Nc
      dummy3D_2(j, i) =  Half*F_t(j, i, k)*Gkw(i)*dummy/beta/Nc
    end do

end subroutine reduc_kernel4

  !------------------------------------
  attributes(global) subroutine reduc_kernel5_0(G_s, G_t, k, idx, One, Two, f_damping, xU, Chi0_pp, dummy3D_3, dummy3D_4, G1, Nt)
    integer, value :: k, idx, Nt
    real(dp), value :: One, xU, f_damping, Two
    complex(dp), value :: G1
    complex(dp) :: Chi0_pp(:), G_s(:, :, :), G_t(:, :, :), dummy3D_3(:, :), dummy3D_4(:, :)

    integer :: i,j
    i = (blockIdx%x-1)*blockDim%x + threadIdx%x
    j = (blockIdx%y-1)*blockDim%y + threadIdx%y
    if (i>Nt .OR. j>Nt) then
      return
    end if

    G_s(i, j, k) = (One-f_damping)*(Two*xU*Chi0_pp(idx)*Two*xU) + f_damping*(dummy3D_3(i, j) - G1 + (Two*xU)*Chi0_pp(idx)*(Two*xU))
    G_t(i, j, k) = f_damping*dummy3D_4(i, j)

  end subroutine reduc_kernel5_0

  !------------------------------------
  attributes(global) subroutine reduc_kernel5_1(G_s, G_t, k, idx, One, Two, f_damping, xU, Chi0_pp, dummy3D_3, dummy3D_4, G1, F_s, F_t, Nt)
    integer, value :: k, idx, Nt
    real(dp), value :: One, xU, f_damping, Two
    complex(dp), value :: G1
    complex(dp) :: Chi0_pp(:), G_s(:, :, :), G_t(:, :, :), dummy3D_3(:, :), dummy3D_4(:, :), F_s(:, :, :), F_t(:, :, :)
    
    integer :: i,j
    i = (blockIdx%x-1)*blockDim%x + threadIdx%x
    j = (blockIdx%y-1)*blockDim%y + threadIdx%y
    if (i > Nt .OR. j>Nt) then
      return
    end if

    G_s(i, j, k) = (One-f_damping)*(F_s(i, j, k)-G_s(i, j, k)) + f_damping*(dummy3D_3(i, j) - G1 + (Two*xU)*Chi0_pp(idx)*(Two*xU))
    G_t(i, j, k) = (One-f_damping)*(F_t(i, j, k)-G_t(i, j, k)) + f_damping*dummy3D_4(i, j)

  end subroutine reduc_kernel5_1
  
  attributes(global) subroutine memSet1D(G, v, Nt)

    integer, value :: Nt
    complex(dp), value :: v
    complex(dp) :: G(:)

    integer :: i
    i = (blockIdx%x-1)*blockDim%x + threadIdx%x
    if (i > Nt) then
      return
    end if

    G(i) = v

  end subroutine memSet1D

  attributes(global) subroutine memSet2D(G, v, Nt)

    integer, value :: Nt
    complex(dp), value :: v
    complex(dp) :: G(:,:)
    
    integer :: i,j
    i = (blockIdx%x-1)*blockDim%x + threadIdx%x
    j = (blockIdx%y-1)*blockDim%y + threadIdx%y
    if (i > Nt .OR. j > Nt) then
      return
    end if

    G(i,j) = v
  
  end subroutine memSet2D

  attributes(global) subroutine memCpySlice(G, V, k, Nt)

    integer, value :: k, Nt
    complex(dp) :: G(:,:), V(:,:,:)
    
    integer :: i,j
    i = (blockIdx%x-1)*blockDim%x + threadIdx%x
    j = (blockIdx%y-1)*blockDim%y + threadIdx%y
    if (i>Nt .OR. j>Nt) then
      return
    end if

    G(i,j) = V(i,j,k)

  end subroutine memCpySlice
  !-------------------------------------------------------------------------------------------
  subroutine reducible_vertex(ite)
     
    integer, intent(in) :: ite

    ! ... local vars ...
    integer     :: i, j, k, idx, istat

    complex(dp) :: G1_sum

    complex(dp), device :: dummy
    complex(dp), allocatable, managed :: G1(:)

    character(len=30) :: FLE, str
    
    complex(dp), device, allocatable :: dummy3D_1(:, :), dummy3D_2(:, :), dummy3D_3(:, :), dummy3D_4(:, :), Gd_slice(:, :), Gm_slice(:, :), Gs_slice(:, :), Gt_slice(:, :)
    type(Indxmap), device :: ComIdx1, ComIdx2
    type(dim3) :: grid, tBlock

    tBlock = dim3(32,4,1)
    grid = dim3((Nt+31)/32, (Nt+3)/4, 1)
    
    if (.NOT. allocated(G1)) allocate(G1(Nt))
    if (.NOT. allocated(dummy3D_1)) allocate(dummy3D_1(Nt, Nt))
    if (.NOT. allocated(dummy3D_2)) allocate(dummy3D_2(Nt, Nt))
    if (.NOT. allocated(dummy3D_3)) allocate(dummy3D_3(Nt, Nt))
    if (.NOT. allocated(dummy3D_4)) allocate(dummy3D_4(Nt, Nt))
    if (.NOT. allocated(Gd_slice)) allocate(Gd_slice(Nt, Nt))
    if (.NOT. allocated(Gm_slice)) allocate(Gm_slice(Nt, Nt))
    if (.NOT. allocated(Gs_slice)) allocate(Gs_slice(Nt, Nt))
    if (.NOT. allocated(Gt_slice)) allocate(Gt_slice(Nt, Nt))
    ! if (.Not. allocated(G1_copy)) allocate(G1_copy(Nt))
    ! if (.Not. allocated(dummy3D_copy)) allocate(dummy3D_copy(Nt, Nt))

    ! G1_copy = Zero_c
    ! dummy3D_copy = Zero_c

    do k = 1, Nb
       idx = id*Nb + k
      
       ! start to calculate the reducible vertex function in particle-hole channel
       G1_sum    = Zero_c

      !  cudaMemcpy(G1, G1_copy, Nt*16, cudaMemcpyDeviceToDevice)
      !  cudaMemcpy(dummy3D_3, dummy3D_copy, Nt*Nt*16, cudaMemcpyDeviceToDevice)
      !  cudaMemcpy(dummy3D_4, dummy3D_copy, Nt*Nt*16, cudaMemcpyDeviceToDevice)
      !  G1 = G1_copy
      !  dummy3D_3 = dummy3D_copy
      !  dummy3D_4 = dummy3D_copy
       call memSet1D<<<(Nt+31)/32, 32>>>(G1, Zero_c, Nt)
       call memSet2D<<<grid, tBlock>>>(dummy3D_3, Zero_c, Nt)
       call memSet2D<<<grid, tBlock>>>(dummy3D_4, Zero_c, Nt)

       call memCpySlice<<<grid, tBlock>>>(Gd_slice, G_d, k, Nt)
       call memCpySlice<<<grid, tBlock>>>(Gm_slice, G_m, k, Nt)
       call memCpySlice<<<grid, tBlock>>>(Gs_slice, G_s, k, Nt)
       call memCpySlice<<<grid, tBlock>>>(Gt_slice, G_t, k, Nt)

       ! --- density (d) and magnetic (m) channels ---
       !  Phi = Gamma *G*G* F
       call reduc_kernel0<<<(Nt+31)/32, 32>>>(idx, ComIdx1, ComIdx2, Nf, One, xi, Pi, beta, Two, mu, Ek, dummy, G1, Gkw, Fermionic, dummy3D_1, dummy3D_2, F_d, F_m, Nc, xU, Index_fermionic, Index_bosonic, Nt, k, Nx, Ny)

      !  call ZGEMM('N', 'N', Nt, Nt, Nt, Half_c, Gd_slice, Nt, dummy3D_1, Nt, Zero_c, dummy3D_3, Nt)
      !  call ZGEMM('N', 'N', Nt, Nt, Nt, Half_c, Gm_slice, Nt, dummy3D_2, Nt, Zero_c, dummy3D_4, Nt)
       call cublasZgemm('N', 'N', Nt, Nt, Nt, Half_c, Gd_slice, Nt, dummy3D_1, Nt, Zero_c, dummy3D_3, Nt)
       call cublasZgemm('N', 'N', Nt, Nt, Nt, Half_c, Gm_slice, Nt, dummy3D_2, Nt, Zero_c, dummy3D_4, Nt)

       call reduc_kernel1<<<(Nt+31)/32, 32>>>(idx, ComIdx1, ComIdx2, Nf, One, xi, Pi, beta, Two, mu, Ek, dummy, G1, Gkw, Fermionic, dummy3D_1, dummy3D_2, F_d, F_m, Nc, xU, Index_fermionic, Index_bosonic, Nt, k, Nx, Ny)

      !  call ZGEMM('N', 'N', Nt, Nt, Nt, Half_c, dummy3D_1, Nt, Gd_slice, Nt, One_c, dummy3D_3, Nt)
      !  call ZGEMM('N', 'N', Nt, Nt, Nt, Half_c, dummy3D_2, Nt, Gm_slice, Nt, One_c, dummy3D_4, Nt)
       call cublasZgemm('N', 'N', Nt, Nt, Nt, Half_c, dummy3D_1, Nt, Gd_slice, Nt, One_c, dummy3D_3, Nt)
       call cublasZgemm('N', 'N', Nt, Nt, Nt, Half_c, dummy3D_2, Nt, Gm_slice, Nt, One_c, dummy3D_4, Nt)

       istat =  cudaDeviceSynchronize()

      G1_sum = sum(G1(1:Nt))

      if (ite == 1) then
        call reduc_kernel2_0<<<grid, tBlock>>>(G_d, G_m, k, idx, One, f_damping, xU, Chi0_ph, dummy3D_3, dummy3D_4, G1_sum, Nt)
      else
        call reduc_kernel2_1<<<grid, tBlock>>>(G_d, G_m, k, idx, One, f_damping, xU, Chi0_ph, dummy3D_3, dummy3D_4, G1_sum, F_d, F_m, Nt)
      end if
    
       ! --- singlet (s) and triplet (t) channel --- 
      !  G1        = Zero_c
      !  dummy3D_3 = Zero_c
      !  dummy3D_4 = Zero_c

      ! cudaMemcpy(G1, G1_copy, Nt*16, cudaMemcpyDeviceToDevice)
      ! cudaMemcpy(dummy3D_3, dummy3D_copy, Nt*Nt*16, cudaMemcpyDeviceToDevice)
      ! cudaMemcpy(dummy3D_4, dummy3D_copy, Nt*Nt*16, cudaMemcpyDeviceToDevice)
      ! G1 = G1_copy
      ! dummy3D_3 = dummy3D_copy
      ! dummy3D_4 = dummy3D_copy
      call memSet1D<<<(Nt+31)/32, 32>>>(G1, Zero_c, Nt)
      call memSet2D<<<grid, tBlock>>>(dummy3D_3, Zero_c, Nt)
      call memSet2D<<<grid, tBlock>>>(dummy3D_4, Zero_c, Nt)

      call reduc_kernel3<<<(Nt+31)/32, 32>>>(idx, ComIdx1, ComIdx2, Nf, One, xi, Pi, beta, Two, mu, Ek, dummy, G1, Gkw, Fermionic, dummy3D_1, dummy3D_2, F_d, F_m, Nc, xU, Index_fermionic, Index_bosonic, Nt, k, Half, F_s, F_t, Nx, Ny)

      !  call ZGEMM('N', 'N', Nt, Nt, Nt, Half_c, Gs_slice, Nt, dummy3D_1, Nt, Zero_c, dummy3D_3, Nt)
      !  call ZGEMM('N', 'N', Nt, Nt, Nt, Half_c, Gt_slice, Nt, dummy3D_2, Nt, Zero_c, dummy3D_4, Nt)
       call cublasZgemm('N', 'N', Nt, Nt, Nt, Half_c, Gs_slice, Nt, dummy3D_1, Nt, Zero_c, dummy3D_3, Nt)
       call cublasZgemm('N', 'N', Nt, Nt, Nt, Half_c, Gt_slice, Nt, dummy3D_2, Nt, Zero_c, dummy3D_4, Nt)

      call reduc_kernel4<<<(Nt+31)/32, 32>>>(idx, ComIdx1, ComIdx2, Nf, One, xi, Pi, beta, Two, mu, Ek, dummy, G1, Gkw, Fermionic, dummy3D_1, dummy3D_2, F_d, F_m, Nc, xU, Index_fermionic, Index_bosonic, Nt, k, Half, F_s, F_t, Nx, Ny)

      !  call ZGEMM('N', 'N', Nt, Nt, Nt, Half_c, dummy3D_1, Nt, Gs_slice, Nt, One_c, dummy3D_3, Nt)
      !  call ZGEMM('N', 'N', Nt, Nt, Nt, Half_c, dummy3D_2, Nt, Gt_slice, Nt, One_c, dummy3D_4, Nt)       
       call cublasZgemm('N', 'N', Nt, Nt, Nt, Half_c, dummy3D_1, Nt, Gs_slice, Nt, One_c, dummy3D_3, Nt)
       call cublasZgemm('N', 'N', Nt, Nt, Nt, Half_c, dummy3D_2, Nt, Gt_slice, Nt, One_c, dummy3D_4, Nt)

       istat =  cudaDeviceSynchronize()

      G1_sum = sum(G1(1:Nt))

      if (ite == 1) then
        call reduc_kernel5_0<<<grid, tBlock>>>(G_s, G_t, k, idx, One, Two, f_damping, xU, Chi0_pp, dummy3D_3, dummy3D_4, G1_sum, Nt)
      else
        call reduc_kernel5_1<<<grid, tBlock>>>(G_s, G_t, k, idx, One, Two, f_damping, xU, Chi0_pp, dummy3D_3, dummy3D_4, G1_sum, F_s, F_t, Nt)
      end if       
    end do

    ! write(str, '(I0.3,a,I0.3)') ite, '-', id
    ! if (Nc <= 2) then
    !    FLE = 'Reducible_V-'//trim(str)
    !    open(unit=1, file=FLE, status='unknown')
    !    do i = 1, Nt
    !       do j = 1, Nt
    !          do k = 1, Nb
    !             write(1, '(3i5, 8f20.12)') i, j, k, G_d(i, j, k), G_m(i, j, k), G_s(i, j, k), G_t(i, j, k)
    !          end do
    !       end do
    !    end do
    ! end if
    ! close(1)

    if (allocated(dummy3D_1)) deallocate(dummy3D_1)
    if (allocated(dummy3D_2)) deallocate(dummy3D_2)
    if (allocated(dummy3D_3)) deallocate(dummy3D_3)
    if (allocated(dummy3D_4)) deallocate(dummy3D_4)
    if (allocated(G1)) deallocate(G1)
    if (allocated(Gd_slice)) deallocate(Gd_slice)
    if (allocated(Gm_slice)) deallocate(Gm_slice)
    if (allocated(Gs_slice)) deallocate(Gs_slice)
    if (allocated(Gt_slice)) deallocate(Gt_slice)

    !!! G_d, G_m, G_s, G_t are now updated, which temporarily store the reducible vertex functions.
       
  end subroutine reducible_vertex

  ! ----------------------------------------------------------------------------------------------------------------
  subroutine get_kernel_function(ite)
    !
    ! Purpose
    ! =======
    !   From the exact reducible vertex function calculated in routine "reducible_Vertex" determine  
    ! the kernel functions by scanning the edge of it. 
    !
    integer, intent(in) :: ite

    ! ... local vars ...
    integer     :: ichannel, i, ic, jc, k
    complex(dp), allocatable :: dummy1(:,:,:), dummy2(:, :, :)
    character(len=30) :: FLE, str


    if (.NOT. allocated(K2_d1)) allocate(K2_d1(Nt, Nc, Nt/2))
    if (.NOT. allocated(K2_m1)) allocate(K2_m1(Nt, Nc, Nt/2))
    if (.NOT. allocated(k2_s1)) allocate(K2_s1(Nt, Nc, Nt/2))
    if (.NOT. allocated(K2_t1)) allocate(K2_t1(Nt, Nc, Nt/2))
    if (.NOT. allocated(K2_d2)) allocate(K2_d2(Nc, Nt, Nt/2))
    if (.NOT. allocated(K2_m2)) allocate(K2_m2(Nc, Nt, Nt/2))
    if (.NOT. allocated(K2_s2)) allocate(K2_s2(Nc, Nt, Nt/2))
    if (.NOT. allocated(K2_t2)) allocate(K2_t2(Nc, Nt, Nt/2))

    ! assign trivial initial values to kernel functions 
    if (ite == 1) then
       K2_d1 = Zero_c
       k2_d2 = Zero_c
       K2_m1 = Zero_c
       K2_m2 = Zero_c
       K2_s1 = Zero_c
       K2_s2 = Zero_c
       K2_t1 = Zero_c
       K2_t2 = Zero_c
    end if



    ! determine K2 on the master node and distribute it to other nodes
    if (.NOT. allocated(dummy1)) allocate(dummy1(Nt, Nc, Nb))
    if (.NOT. allocated(dummy2)) allocate(dummy2(Nc, Nt, Nb))

    dummy1 = Zero_c
    dummy2 = Zero_c
    do ichannel = 1, 4
       do k = 1, Nb
             ! here we will simply scan the edge of the reducible vertex function to get kernel
             do i = 1, Nt
                do jc = 1, Nc
                   select case (ichannel)
                   case (1)
                      dummy1(i, jc, k) = G_d(i, jc*Nf, k)
                      dummy2(jc, i, k) = G_d(jc*Nf, i, k)
                   case (2)
                      dummy1(i, jc, k) = G_m(i, jc*Nf, k)
                      dummy2(jc, i, k) = G_m(jc*Nf, i, k)
                   case (3)
                      dummy1(i, jc, k) = G_s(i, (jc-1)*Nf+1, k)
                      dummy2(jc, i, k) = G_s((jc-1)*Nf+1, i, k)
                   case (4)
                      dummy1(i, jc, k) = G_t(i, (jc-1)*Nf+1, k)
                      dummy2(jc, i, k) = G_t((jc-1)*Nf+1, i, k)
                   end select
                end do
             end do
       end do

       if (id == master) then
          select case (ichannel)
          case (1)
             K2_d1(1:Nt, 1:Nc, 1:Nb) = dummy1(1:Nt, 1:Nc, 1:Nb)
             K2_d2(1:Nc, 1:Nt, 1:Nb) = dummy2(1:Nc, 1:Nt, 1:Nb)
          case (2) 
             K2_m1(1:Nt, 1:Nc, 1:Nb) = dummy1(1:Nt, 1:Nc, 1:Nb)
             K2_m2(1:Nc, 1:Nt, 1:Nb) = dummy2(1:Nc, 1:Nt, 1:Nb)
          case (3)
             K2_s1(1:Nt, 1:Nc, 1:Nb) = dummy1(1:Nt, 1:Nc, 1:Nb)
             K2_s2(1:Nc, 1:Nt, 1:Nb) = dummy2(1:Nc, 1:Nt, 1:Nb)
          case (4)
             K2_t1(1:Nt, 1:Nc, 1:Nb) = dummy1(1:Nt, 1:Nc, 1:Nb)
             K2_t2(1:Nc, 1:Nt, 1:Nb) = dummy2(1:Nc, 1:Nt, 1:Nb)
          end select
          do i = 1, ntasks-1
             call MPI_RECV(dummy1, Nt*Nc*Nb, MPI_DOUBLE_COMPLEX, i, i, MPI_COMM_WORLD, status, rc)
             call MPI_RECV(dummy2, Nt*Nc*Nb, MPI_DOUBLE_COMPLEX, i, i, MPI_COMM_WORLD, status, rc)
             select case (ichannel)
             case (1)
                K2_d1(1:Nt, 1:Nc, (i*Nb+1):(i+1)*Nb) = dummy1(1:Nt, 1:Nc, 1:Nb)
                K2_d2(1:Nc, 1:Nt, (i*Nb+1):(i+1)*Nb) = dummy2(1:Nc, 1:Nt, 1:Nb)
             case (2)
                K2_m1(1:Nt, 1:Nc, (i*Nb+1):(i+1)*Nb) = dummy1(1:Nt, 1:Nc, 1:Nb)
                K2_m2(1:Nc, 1:Nt, (i*Nb+1):(i+1)*Nb) = dummy2(1:Nc, 1:Nt, 1:Nb)
             case (3)
                K2_s1(1:Nt, 1:Nc, (i*Nb+1):(i+1)*Nb) = dummy1(1:Nt, 1:Nc, 1:Nb)
                K2_s2(1:Nc, 1:Nt, (i*Nb+1):(i+1)*Nb) = dummy2(1:Nc, 1:Nt, 1:Nb)
             case (4)
                K2_t1(1:Nt, 1:Nc, (i*Nb+1):(i+1)*Nb) = dummy1(1:Nt, 1:Nc, 1:Nb)
                K2_t2(1:Nc, 1:Nt, (i*Nb+1):(i+1)*Nb) = dummy2(1:Nc, 1:Nt, 1:Nb)
             end select
          end do
       else
          call MPI_SEND(dummy1, Nt*Nc*Nb, MPI_DOUBLE_COMPLEX, master, id, MPI_COMM_WORLD, rc)
          call MPI_SEND(dummy2, Nt*Nc*Nb, MPI_DOUBLE_COMPLEX, master, id, MPI_COMM_WORLD, rc)
       end if
    end do

    call MPI_BCAST(K2_d1, Nc*Nt*Nt/2, MPI_DOUBLE_COMPLEX, master, MPI_COMM_WORLD, rc)
    call MPI_BCAST(K2_d2, Nc*Nt*Nt/2, MPI_DOUBLE_COMPLEX, master, MPI_COMM_WORLD, rc)
    call MPI_BCAST(K2_m1, Nc*Nt*Nt/2, MPI_DOUBLE_COMPLEX, master, MPI_COMM_WORLD, rc)
    call MPI_BCAST(K2_m2, Nc*Nt*Nt/2, MPI_DOUBLE_COMPLEX, master, MPI_COMM_WORLD, rc)
    call MPI_BCAST(K2_s1, Nc*Nt*Nt/2, MPI_DOUBLE_COMPLEX, master, MPI_COMM_WORLD, rc)
    call MPI_BCAST(K2_s2, Nc*Nt*Nt/2, MPI_DOUBLE_COMPLEX, master, MPI_COMM_WORLD, rc)
    call MPI_BCAST(K2_t1, Nc*Nt*Nt/2, MPI_DOUBLE_COMPLEX, master, MPI_COMM_WORLD, rc)
    call MPI_BCAST(K2_t2, Nc*Nt*Nt/2, MPI_DOUBLE_COMPLEX, master, MPI_COMM_WORLD, rc)

    if (id == master) then
       write(str, '(I0.3)') ite
       FLE = 'K2-'//trim(str)//'.dat'
       open(unit = 1, file = FLE, status = 'unknown')
       do i = 1, Nt
          do ic = 1, Nc 
             do k = 1, Nt/2
                write(1, '(3i4, 16f10.5)') i, ic, k, K2_d1(i,ic,k), K2_d2(ic,i,k), K2_m1(i,ic,k), K2_m2(ic,i,k), &
                     K2_s1(i,ic,k), K2_s2(ic,i,k), K2_t1(i,ic,k), K2_t2(ic,i,k)
             end do
             write(1, *) 
          end do
       end do
       close(1)
    end if
    
    if (allocated(dummy1)) deallocate(dummy1)
    if (allocated(dummy2)) deallocate(dummy2)

  end subroutine get_kernel_function
 
  !-------------------------------------------------------------------------------------------------
  complex(dp) function kernel(channel, k1, k2, q)
    
    ! character(len=1), intent(in) :: channel
    integer, intent(in) :: channel
    type(Indxmap),    intent(in) :: k1, k2, q
  
    ! ... local vars ...
    integer       :: ic, jc, qc, iw, jw, qw, idx, idx1 
    type(Indxmap) :: k1_, k2_, q_
    complex(dp)   :: background
    
    if (q%iw > 0) then
       k1_ = k1
       k2_ = k2
        q_ = q
    else
       call index_operation(k1, k1, MinusF, K1_)
       call index_operation(k2, k2, MinusF, K2_)
       call index_operation(q, q, MinusB, q_)
    end if

    ic = (k1_%ix-1)*Ny+k1_%iy
    jc = (k2_%ix-1)*Ny+k2_%iy
    qc = (q_%ix-1)*Ny+q_%iy
    iw = k1_%iw
    jw = k2_%iw
    qw = q_%iw

    idx  = ((k1_%ix-1)*Ny+k1_%iy)*Nf
    idx1 = ((k1_%ix-1)*Ny+k1_%iy-1)*Nf+1 

    kernel = Zero
    if (qw > Nf/2) return

    select case (channel)
    case (CHANNEL_D)
    
          background = K2_d1(idx, jc, list_index(q_, Bosonic))

       if (iw > Nf .or. iw < 1) then  ! k1 is out of range
          if (jw > Nf .or. jw < 1) then  ! k2 if out of range
             kernel = background
          else
             kernel = K2_d2(ic, list_index(K2_, Fermionic), list_index(q_, Bosonic))
          end if
       else
          if (jw > Nf .or. jw < 1) then
             kernel = K2_d1(list_index(k1_, Fermionic), jc, list_index(q_, Bosonic))
          else
             Kernel = K2_d1(list_index(k1_, Fermionic), jc, list_index(q_, Bosonic)) + K2_d2(ic, list_index(k2_, Fermionic), list_index(q_, Bosonic)) - background
          end if
       end if       
    case (CHANNEL_M)
          background = K2_m1(idx, jc, list_index(q_, Bosonic))
       if (iw > Nf .or. iw < 1) then  ! k1 is out of range
          if (jw > Nf .or. jw < 1) then  ! k2 if out of range
             kernel = background
          else
             kernel = K2_m2(ic, list_index(K2_, Fermionic), list_index(q_, Bosonic))
          end if
       else
          if (jw > Nf .or. jw < 1) then
             kernel = K2_m1(list_index(k1_, Fermionic), jc, list_index(q_, Bosonic))
          else
             Kernel = K2_m1(list_index(k1_, Fermionic), jc, list_index(q_, Bosonic)) + K2_m2(ic, list_index(k2_, Fermionic), list_index(q_, Bosonic)) - background
          end if
       end if
    case (CHANNEL_S)
          background = K2_s1(idx1, jc, list_index(q_, Bosonic))
       if (iw > Nf .or. iw < 1) then  ! k1 is out of range
          if (jw > Nf .or. jw < 1) then  ! k2 if out of range
             kernel = background
          else
             kernel = K2_s2(ic, list_index(K2_, Fermionic), list_index(q_, Bosonic))
          end if
       else
          if (jw > Nf .or. jw < 1) then
             kernel = K2_s1(list_index(k1_, Fermionic), jc, list_index(q_, Bosonic))
          else
             Kernel = K2_s1(list_index(k1_, Fermionic), jc, list_index(q_, Bosonic)) + K2_s2(ic, list_index(k2_, Fermionic), list_index(q_, Bosonic)) - background
          end if
       end if
    case (CHANNEL_T)
          background = K2_t1(idx1, jc, list_index(q_, Bosonic))
       if (iw > Nf .or. iw < 1) then  ! k1 is out of range
          if (jw > Nf .or. jw < 1) then  ! k2 if out of range
             kernel = background
          else
             kernel = K2_t2(ic, list_index(K2_, Fermionic), list_index(q_, Bosonic))
          end if
       else
          if (jw > Nf .or. jw < 1) then
             kernel = K2_t1(list_index(k1_, Fermionic), jc, list_index(q_, Bosonic))
          else
             Kernel = K2_t1(list_index(k1_, Fermionic), jc, list_index(q_, Bosonic)) + K2_t2(ic, list_index(k2_, Fermionic), list_index(q_, Bosonic)) - background
          end if
       end if
    end select
     
    if (q%iw < 1)  Kernel = conjg(Kernel)

  end function kernel 
  

  
end module Parquet_kernel
