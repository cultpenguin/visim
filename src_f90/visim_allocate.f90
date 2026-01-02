!-----------------------------------------------------------------------
! VISIM Allocation Helper Routines
! ---------------------------------
! Centralized allocation and deallocation of all VISIM arrays
! This module provides high-level routines that call the individual
! module allocation subroutines.
!-----------------------------------------------------------------------

module visim_allocate
  use visim_params_mod
  use visim_data_mod
  use visim_grid_mod
  use visim_volume_mod
  use visim_covariance_mod
  use visim_kriging_mod
  use visim_search_mod
  use visim_histogram_mod
  implicit none

contains

!-----------------------------------------------------------------------
! allocate_all_arrays - Allocate all dynamic arrays
! This is called after dimension requirements are determined
!-----------------------------------------------------------------------
subroutine allocate_all_arrays(maxdat, maxvols, maxdinvol, &
                                 maxnod, maxsam, maxnst, &
                                 maxctx, maxcty, maxctz, &
                                 maxsbx, maxsby, maxsbz, &
                                 maxquan, maxmvlook, maxref, maxcat, &
                                 nx_in, ny_in, nz_in, ierr)
  integer, intent(in) :: maxdat, maxvols, maxdinvol
  integer, intent(in) :: maxnod, maxsam, maxnst
  integer, intent(in) :: maxctx, maxcty, maxctz
  integer, intent(in) :: maxsbx, maxsby, maxsbz
  integer, intent(in) :: maxquan, maxmvlook, maxref, maxcat
  integer, intent(in) :: nx_in, ny_in, nz_in
  integer, intent(out) :: ierr
  integer :: nxyz

  ierr = 0
  nxyz = nx_in * ny_in * nz_in

  write(*,*)
  write(*,*) '======================================================='
  write(*,*) 'VISIM F90 - Dynamic Memory Allocation'
  write(*,*) '======================================================='
  write(*,*)
  write(*,'(A,I0,A,I0,A,I0,A,I0)') '  Grid: ', nx_in, ' x ', ny_in, &
                                   ' x ', nz_in, ' = ', nxyz, ' nodes'
  write(*,'(A,I0)') '  Max data points: ', maxdat
  write(*,'(A,I0,A,I0)') '  Max volumes: ', maxvols, &
                         ' (max points/volume: ', maxdinvol, ')'
  write(*,'(A,I0,A,I0)') '  Kriging: max nodes=', maxnod, &
                         ', max samples=', maxsam
  write(*,*)

  ! Estimate total memory requirement
  call estimate_memory_requirements(nx_in, ny_in, nz_in, maxvols, &
                                    maxdinvol, maxdat, maxnod, maxsam, &
                                    maxquan, maxmvlook)
  write(*,*)

  ! Allocate data arrays
  write(*,*) '1. Allocating data arrays...'
  call allocate_data_arrays(maxdat, maxref, maxcat)

  ! Allocate grid arrays
  write(*,*) '2. Allocating grid arrays...'
  call allocate_grid_arrays(nx_in, ny_in, nz_in)

  ! Allocate volume arrays
  write(*,*) '3. Allocating volume arrays...'
  call allocate_volume_arrays(maxvols, maxdinvol)

  ! Allocate covariance arrays
  write(*,*) '4. Allocating covariance arrays (may be large)...'
  call allocate_covariance_arrays(maxnst, maxctx, maxcty, maxctz, &
                                   maxnod, maxvols, nxyz)

  ! Allocate kriging arrays
  write(*,*) '5. Allocating kriging arrays...'
  call allocate_kriging_arrays(maxnod, maxsam)

  ! Allocate search arrays
  write(*,*) '6. Allocating search arrays...'
  call allocate_search_arrays(maxsbx, maxsby, maxsbz)

  ! Allocate histogram arrays (if using DSSIM)
  write(*,*) '7. Allocating histogram/DSSIM arrays...'
  call allocate_histogram_arrays(maxmvlook, maxquan)

  write(*,*)
  write(*,*) '======================================================='
  write(*,*) 'All arrays allocated successfully!'
  write(*,*) '======================================================='
  write(*,*)

end subroutine allocate_all_arrays

!-----------------------------------------------------------------------
! deallocate_all_arrays - Free all dynamic arrays
!-----------------------------------------------------------------------
subroutine deallocate_all_arrays()

  write(*,*)
  write(*,*) 'Deallocating all arrays...'

  call deallocate_data_arrays()
  call deallocate_grid_arrays()
  call deallocate_volume_arrays()
  call deallocate_covariance_arrays()
  call deallocate_kriging_arrays()
  call deallocate_search_arrays()
  call deallocate_histogram_arrays()

  write(*,*) 'All arrays deallocated successfully.'
  write(*,*)

end subroutine deallocate_all_arrays

!-----------------------------------------------------------------------
! estimate_memory_requirements - Estimate total memory before allocation
!-----------------------------------------------------------------------
subroutine estimate_memory_requirements(nx, ny, nz, maxvols, maxdinvol, &
                                         maxdat, maxnod, maxsam, &
                                         maxquan, maxmvlook)
  integer, intent(in) :: nx, ny, nz, maxvols, maxdinvol
  integer, intent(in) :: maxdat, maxnod, maxsam
  integer, intent(in) :: maxquan, maxmvlook
  integer :: nxyz, maxkr1, maxkr2
  integer(kind=8) :: memory_bytes, cd2v_bytes
  integer :: memory_mb

  nxyz = nx * ny * nz
  maxkr1 = maxnod + maxsam + 1
  maxkr2 = maxkr1 * maxkr1

  memory_bytes = 0

  ! Grid arrays: sim, lvm, tmp, order, dvr, krgvar, mask, novar
  ! (6 real + 2 integer = 32 bytes per grid point)
  memory_bytes = memory_bytes + int8(nxyz) * 32

  ! Data arrays: ~15 arrays of size maxdat (mostly real = 4 bytes)
  memory_bytes = memory_bytes + int8(maxdat) * 60

  ! Volume arrays: volx, voly, volz, voll (4 real*4) + voli (1 int*4)
  ! = 20 bytes per (volume, point in volume) pair
  memory_bytes = memory_bytes + int8(maxvols) * int8(maxdinvol) * 20

  ! Covariance tables (CRITICAL - largest consumers)
  ! covtab: nx*ny*nz * 4 bytes (real*4)
  memory_bytes = memory_bytes + int8(nxyz) * 4

  ! cv2v: maxvols*maxvols * 8 bytes (real*8)
  memory_bytes = memory_bytes + int8(maxvols) * int8(maxvols) * 8

  ! cd2v: nxyz*maxvols * 8 bytes (real*8) - LARGEST ARRAY!
  cd2v_bytes = int8(nxyz) * int8(maxvols) * 8
  memory_bytes = memory_bytes + cd2v_bytes

  ! datacov: maxvols*maxvols * 4 bytes (real*4)
  memory_bytes = memory_bytes + int8(maxvols) * int8(maxvols) * 4

  ! Kriging matrix: maxkr2 * 8 bytes (real*8)
  memory_bytes = memory_bytes + int8(maxkr2) * 8

  ! DSSIM lookup: condlookup_cpdf is maxmvlook*maxmvlook*maxquan
  memory_bytes = memory_bytes + int8(maxmvlook) * int8(maxmvlook) * int8(maxquan) * 4

  memory_mb = int(memory_bytes / (1024 * 1024))

  write(*,*) 'Estimated memory requirements:'
  write(*,'(A,I0,A)') '  Grid arrays:        ', nxyz*32/1024/1024, ' MB'
  write(*,'(A,I0,A)') '  Data arrays:        ', maxdat*60/1024/1024, ' MB'
  write(*,'(A,I0,A)') '  Volume arrays:      ', &
            int8(maxvols)*int8(maxdinvol)*20/1024/1024, ' MB'
  write(*,'(A,I0,A)') '  Kriging matrix:     ', maxkr2*8/1024/1024, ' MB'
  write(*,'(A,I0,A)') '  cv2v covariance:    ', &
            int8(maxvols)*int8(maxvols)*8/1024/1024, ' MB'
  write(*,'(A,I0,A)') '  cd2v covariance:    ', cd2v_bytes/1024/1024, &
            ' MB  <-- LARGEST!'
  write(*,'(A,I0,A)') '  DSSIM lookups:      ', &
            int8(maxmvlook)*int8(maxmvlook)*int8(maxquan)*4/1024/1024, ' MB'
  write(*,*) '  ------------------------------------------------'
  write(*,'(A,I0,A)') '  TOTAL ESTIMATED:    ', memory_mb, ' MB'

  if (memory_mb > 4000) then
    write(*,*)
    write(*,*) 'WARNING: Memory requirement exceeds 4 GB!'
    write(*,*) '         Consider reducing grid size or number of volumes.'
    write(*,*) '         Or use read_covtable=1 to read covariance from file.'
  end if

end subroutine estimate_memory_requirements

!-----------------------------------------------------------------------
! validate_dimensions - Check that runtime dimensions don't exceed allocated
!-----------------------------------------------------------------------
subroutine validate_dimensions()
  use visim_params_mod
  use visim_data_mod
  use visim_grid_mod
  use visim_volume_mod

  logical :: error_found

  error_found = .false.

  ! Check grid dimensions
  if (nx * ny * nz > mxyz_max) then
    write(*,*) 'ERROR: Grid size exceeds allocated memory'
    write(*,*) '  Requested: ', nx, 'x', ny, 'x', nz, ' = ', nx*ny*nz
    write(*,*) '  Allocated: ', mxyz_max
    error_found = .true.
  end if

  ! Check data count
  if (nd > nd_max) then
    write(*,*) 'ERROR: Number of data exceeds allocated memory'
    write(*,*) '  Data points: ', nd
    write(*,*) '  Allocated: ', nd_max
    error_found = .true.
  end if

  ! Check volume count
  if (nvol > nvol_max) then
    write(*,*) 'ERROR: Number of volumes exceeds allocated memory'
    write(*,*) '  Volumes: ', nvol
    write(*,*) '  Allocated: ', nvol_max
    error_found = .true.
  end if

  if (error_found) then
    stop 'DIMENSION_EXCEEDED'
  end if

end subroutine validate_dimensions

end module visim_allocate
