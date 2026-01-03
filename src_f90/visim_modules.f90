!%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
!                                                                      %
! Copyright (C) 1996, The Board of Trustees of the Leland Stanford    %
! Junior University.  All rights reserved.                            %
!                                                                      %
! Modernized to Fortran 90 with dynamic memory allocation - 2026      %
!                                                                      %
!%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
!
! VISIM Fortran 90 Modules
! ------------------------
! This file contains all modules that replace the COMMON blocks from
! the original Fortran 77 visim.inc file. Arrays are now dynamically
! allocated at runtime based on problem dimensions.
!

!-----------------------------------------------------------------------
! Module 1: visim_params_mod
! Purpose: Constants, scalar parameters, and file units
! Replaces: /generl/ (scalar parts), /kurto/, constants from visim.inc
!-----------------------------------------------------------------------
module visim_params_mod
  implicit none

  ! Version and mathematical constants
  real, parameter :: VERSION = 2.0
  real, parameter :: UNEST = -9999999.0
  real, parameter :: EPSLON = 1.0e-20
  integer, parameter :: KORDEI = 12
  integer, parameter :: MAXOP1 = KORDEI + 1
  integer, parameter :: MAXINT = 2**30

  ! Grid dimensions (runtime-determined)
  integer :: nx, ny, nz        ! actual grid dimensions
  integer :: nxy, nxyz         ! derived: nx*ny and nx*ny*nz
  real :: xsiz, ysiz, zsiz     ! cell sizes
  real :: xmn, ymn, zmn        ! minimum coordinates

  ! Data parameters
  integer :: nd                ! actual number of data points
  integer :: ntr               ! number of transformed data

  ! File units
  integer :: lin, lout, ldbg, llvm, lkv
  integer :: lout_mean, lout_std, lout_krig

  ! Simulation control
  integer :: nsim              ! number of realizations
  integer :: isim              ! current realization number
  integer :: doestimation      ! 0=simulation, 1=estimation only
  integer :: icond             ! conditioning flag
  integer :: idbg              ! debug level
  integer :: ktype             ! kriging type
  integer :: ivar              ! variance flag
  integer :: icollvm           ! local varying mean flag
  integer :: nvaril            ! variable for LVM

  ! Drawing and kurtosis (from /kurto/)
  integer :: idrawopt          ! drawing option
  real :: ckurt                ! target kurtosis
  real :: pkr                  ! kurtosis power

  ! Transformation parameters (scalar parts)
  integer :: ltail, utail      ! lower/upper tail options
  real :: ltpar, utpar         ! tail parameters
  real :: zmin, zmax           ! data trimming limits
  real :: tmin, tmax           ! transformation limits
  real :: varred               ! variance reduction factor
  real :: skgmean              ! simple kriging global mean
  real :: gvar                 ! global variance
  real :: porvar               ! porosity variance
  real :: colocorr             ! collocated correlation

  ! Transformation options
  integer :: itrans            ! transformation flag
  integer :: ivrr, iwtr        ! variance reduction flags
  integer :: ivrd, iwtd        ! data flags
  integer :: ncut              ! number of cutoffs
  integer :: wx, wy, wz        ! weight dimensions
  integer :: icoll             ! collocated flag
  real :: wtfac                ! weight factor
  real :: rn                   ! random number
  real :: wtt, vrt, wtd, vrd   ! weight/variance temps

  ! Bootstrap parameters
  integer :: ibt, ibtw, nbt    ! bootstrap flags and count
  real :: btmean, btvar        ! bootstrap mean/variance

  ! Volume integration parameters (scalars)
  integer :: nvol              ! number of volumes
  integer :: nusev             ! number of volumes actually used
  integer :: musevols          ! use volumes flag
  integer :: nusevols          ! number of volumes to use
  integer :: shuffvol          ! shuffle volumes flag
  integer :: shuffinvol        ! shuffle data in volumes flag
  integer :: densitypr         ! density prior flag
  real :: accept_fract         ! acceptance fraction for volumes

  ! DSSIM parameters
  integer :: n_Gmean, n_Gvar, n_q, n_monte, discrete
  real :: min_Gmean, max_Gmean
  real :: min_Gvar, max_Gvar

  ! File names
  character(len=40) :: distin, localfl, outfl, transoutfl, lambdafl

  ! File reading flags
  integer :: read_covtable, read_lambda, read_volnh, read_randpath
  integer :: do_cholesky, do_error_sim

end module visim_params_mod

!-----------------------------------------------------------------------
! Module 2: visim_data_mod
! Purpose: Conditioning data arrays (dynamically allocated)
! Replaces: /generl/ (data array parts), /transcon/ (data arrays)
!-----------------------------------------------------------------------
module visim_data_mod
  implicit none

  ! Data array maximum sizes (set at allocation time)
  integer :: nd_max      ! MAXDAT
  integer :: nref_max    ! MAXREF
  integer :: ncat_max    ! MAXCAT

  ! Conditioning data arrays (allocated to nd_max)
  real, allocatable :: x(:), y(:), z(:)      ! coordinates
  real, allocatable :: vr(:)                 ! values
  real, allocatable :: wt(:)                 ! weights
  real, allocatable :: vrtr(:), vrgtr(:)     ! transformed values
  real, allocatable :: sec(:)                ! secondary variable
  real, allocatable :: close(:)              ! close data indices

  ! Transformation arrays
  real, allocatable :: dcdf(:)               ! data CDF
  real, allocatable :: indx(:)               ! indices
  real, allocatable :: fuzzcat(:)            ! fuzzy categories
  integer, allocatable :: category(:)        ! categories

  ! Reference distribution (allocated to nref_max)
  real, allocatable :: rcdf(:), rvr(:)       ! reference CDF and values

  ! Category CDF (allocated to ncat_max)
  real, allocatable :: catcdf(:)             ! category CDF

  ! Bootstrap arrays (allocated to nd_max)
  real, allocatable :: bootvar(:)            ! bootstrap variance
  real, allocatable :: bootwt(:)             ! bootstrap weights
  real, allocatable :: bootcdf(:)            ! bootstrap CDF

contains

  subroutine allocate_data_arrays(maxdat, maxref, maxcat)
    integer, intent(in) :: maxdat, maxref, maxcat
    integer :: ierr

    nd_max = maxdat
    nref_max = maxref
    ncat_max = maxcat

    ! Allocate coordinate and value arrays
    allocate(x(maxdat), y(maxdat), z(maxdat), stat=ierr)
    if (ierr /= 0) then
      write(*,*) 'ERROR: Failed to allocate x, y, z arrays'
      stop 'ALLOCATION_FAILURE'
    end if

    allocate(vr(maxdat), wt(maxdat), stat=ierr)
    if (ierr /= 0) then
      write(*,*) 'ERROR: Failed to allocate vr, wt arrays'
      stop 'ALLOCATION_FAILURE'
    end if

    allocate(vrtr(maxdat), vrgtr(maxdat), sec(maxdat), close(maxdat), stat=ierr)
    if (ierr /= 0) then
      write(*,*) 'ERROR: Failed to allocate transformed data arrays'
      stop 'ALLOCATION_FAILURE'
    end if

    allocate(dcdf(maxdat), indx(maxdat), fuzzcat(maxdat), stat=ierr)
    if (ierr /= 0) then
      write(*,*) 'ERROR: Failed to allocate transformation arrays'
      stop 'ALLOCATION_FAILURE'
    end if

    allocate(category(maxdat), stat=ierr)
    if (ierr /= 0) then
      write(*,*) 'ERROR: Failed to allocate category array'
      stop 'ALLOCATION_FAILURE'
    end if

    allocate(bootvar(maxdat), bootwt(maxdat), bootcdf(maxdat), stat=ierr)
    if (ierr /= 0) then
      write(*,*) 'ERROR: Failed to allocate bootstrap arrays'
      stop 'ALLOCATION_FAILURE'
    end if

    ! Reference distribution
    allocate(rcdf(maxref), rvr(maxref), stat=ierr)
    if (ierr /= 0) then
      write(*,*) 'ERROR: Failed to allocate reference distribution arrays'
      stop 'ALLOCATION_FAILURE'
    end if

    ! Category CDF
    allocate(catcdf(maxcat), stat=ierr)
    if (ierr /= 0) then
      write(*,*) 'ERROR: Failed to allocate catcdf array'
      stop 'ALLOCATION_FAILURE'
    end if

  end subroutine allocate_data_arrays

  subroutine deallocate_data_arrays()
    if (allocated(x)) deallocate(x, y, z)
    if (allocated(vr)) deallocate(vr, wt)
    if (allocated(vrtr)) deallocate(vrtr, vrgtr, sec, close)
    if (allocated(dcdf)) deallocate(dcdf, indx, fuzzcat)
    if (allocated(category)) deallocate(category)
    if (allocated(bootvar)) deallocate(bootvar, bootwt, bootcdf)
    if (allocated(rcdf)) deallocate(rcdf, rvr)
    if (allocated(catcdf)) deallocate(catcdf)
  end subroutine deallocate_data_arrays

end module visim_data_mod

!-----------------------------------------------------------------------
! Module 3: visim_grid_mod
! Purpose: Simulation grid arrays (dynamically allocated)
! Replaces: /simula/, grid arrays from /generl/
!-----------------------------------------------------------------------
module visim_grid_mod
  implicit none

  integer :: mxyz_max          ! Maximum grid size (nx*ny*nz)

  ! Grid arrays (allocated to mxyz_max = nx*ny*nz)
  real, allocatable :: sim(:)       ! simulated values
  real, allocatable :: lvm(:)       ! local varying mean
  real, allocatable :: tmp(:)       ! temporary array
  real, allocatable :: order(:)     ! random path order
  real, allocatable :: dvr(:)       ! data variance reduction
  real, allocatable :: krgvar(:)    ! kriging variance
  integer, allocatable :: mask(:)   ! simulation mask
  integer, allocatable :: novar(:)  ! no variance flag

  ! 2D porosity array (allocated to nx x ny)
  real, allocatable :: avepor(:,:)  ! average porosity

contains

  subroutine allocate_grid_arrays(nx, ny, nz)
    integer, intent(in) :: nx, ny, nz
    integer :: nxyz, ierr

    nxyz = nx * ny * nz
    mxyz_max = nxyz

    write(*,'(A,I0,A,I0,A,I0,A,I0)') &
      'Allocating grid arrays: ', nx, ' x ', ny, ' x ', nz, ' = ', nxyz

    allocate(sim(nxyz), lvm(nxyz), tmp(nxyz), stat=ierr)
    if (ierr /= 0) then
      write(*,*) 'ERROR: Failed to allocate sim/lvm/tmp arrays'
      write(*,*) '  Requested size: ', nxyz, ' elements'
      write(*,*) '  Memory required: ~', nxyz*12/1024/1024, ' MB'
      stop 'ALLOCATION_FAILURE'
    end if

    allocate(order(nxyz), dvr(nxyz), krgvar(nxyz), stat=ierr)
    if (ierr /= 0) then
      write(*,*) 'ERROR: Failed to allocate order/dvr/krgvar arrays'
      stop 'ALLOCATION_FAILURE'
    end if

    allocate(mask(nxyz), novar(nxyz), stat=ierr)
    if (ierr /= 0) then
      write(*,*) 'ERROR: Failed to allocate mask/novar arrays'
      stop 'ALLOCATION_FAILURE'
    end if

    ! Initialize mask to 1 (simulate all nodes)
    mask = 1

    allocate(avepor(nx, ny), stat=ierr)
    if (ierr /= 0) then
      write(*,*) 'ERROR: Failed to allocate avepor array'
      stop 'ALLOCATION_FAILURE'
    end if

    write(*,'(A,I0,A)') '  Grid arrays allocated successfully (', &
                        nxyz*32/1024/1024, ' MB)'

  end subroutine allocate_grid_arrays

  subroutine deallocate_grid_arrays()
    if (allocated(sim)) deallocate(sim, lvm, tmp)
    if (allocated(order)) deallocate(order, dvr, krgvar)
    if (allocated(mask)) deallocate(mask, novar)
    if (allocated(avepor)) deallocate(avepor)
  end subroutine deallocate_grid_arrays

end module visim_grid_mod

!-----------------------------------------------------------------------
! Module 4: visim_volume_mod
! Purpose: Volume integration data (dynamically allocated)
! Replaces: /volume/
!-----------------------------------------------------------------------
module visim_volume_mod
  implicit none

  integer :: nvol_max, ndinvol_max
  integer :: maxvols_dim, maxdinvol_dim  ! Max dimensions for bounds checking

  ! Volume summary arrays (allocated to nvol_max)
  integer, allocatable :: ndatainvol(:)    ! data count per volume
  real, allocatable :: volobs(:)           ! volume observations
  real, allocatable :: volvar(:)           ! volume variances
  real, allocatable :: volobs_ref(:)       ! volume reference observations
  integer, allocatable :: usev(:)          ! volumes to use

  ! Volume geometry arrays (allocated to nvol_max x ndinvol_max)
  real, allocatable :: volx(:,:)           ! X coordinates
  real, allocatable :: voly(:,:)           ! Y coordinates
  real, allocatable :: volz(:,:)           ! Z coordinates
  real, allocatable :: voll(:,:)           ! integration weights
  integer, allocatable :: voli(:,:)        ! volume indices

contains

  subroutine allocate_volume_arrays(maxvols, maxdinvol)
    integer, intent(in) :: maxvols, maxdinvol
    integer :: ierr

    nvol_max = maxvols
    ndinvol_max = maxdinvol
    maxvols_dim = maxvols
    maxdinvol_dim = maxdinvol

    write(*,'(A,I0,A,I0)') 'Allocating volume arrays: ', &
                           maxvols, ' x ', maxdinvol

    ! Volume summary arrays
    allocate(ndatainvol(maxvols), stat=ierr)
    if (ierr /= 0) then
      write(*,*) 'ERROR: Failed to allocate ndatainvol array'
      stop 'ALLOCATION_FAILURE'
    end if

    allocate(volobs(maxvols), volvar(maxvols), volobs_ref(maxvols), stat=ierr)
    if (ierr /= 0) then
      write(*,*) 'ERROR: Failed to allocate volume observation arrays'
      stop 'ALLOCATION_FAILURE'
    end if

    allocate(usev(maxvols), stat=ierr)
    if (ierr /= 0) then
      write(*,*) 'ERROR: Failed to allocate usev array'
      stop 'ALLOCATION_FAILURE'
    end if

    ! Volume geometry arrays
    allocate(volx(maxvols, maxdinvol), stat=ierr)
    if (ierr /= 0) then
      write(*,*) 'ERROR: Failed to allocate volx array'
      write(*,*) '  Memory required: ~', maxvols*maxdinvol*4/1024/1024, ' MB'
      stop 'ALLOCATION_FAILURE'
    end if

    allocate(voly(maxvols, maxdinvol), volz(maxvols, maxdinvol), stat=ierr)
    if (ierr /= 0) then
      write(*,*) 'ERROR: Failed to allocate voly/volz arrays'
      stop 'ALLOCATION_FAILURE'
    end if

    allocate(voll(maxvols, maxdinvol), voli(maxvols, maxdinvol), stat=ierr)
    if (ierr /= 0) then
      write(*,*) 'ERROR: Failed to allocate voll/voli arrays'
      stop 'ALLOCATION_FAILURE'
    end if

    write(*,'(A,I0,A)') '  Volume arrays allocated successfully (', &
                        maxvols*maxdinvol*20/1024/1024, ' MB)'

  end subroutine allocate_volume_arrays

  subroutine deallocate_volume_arrays()
    if (allocated(ndatainvol)) deallocate(ndatainvol)
    if (allocated(volobs)) deallocate(volobs, volvar, volobs_ref)
    if (allocated(usev)) deallocate(usev)
    if (allocated(volx)) deallocate(volx, voly, volz, voll, voli)
  end subroutine deallocate_volume_arrays

end module visim_volume_mod

!-----------------------------------------------------------------------
! Module 5: visim_covariance_mod
! Purpose: Covariance models, tables, and lookup structures
! Replaces: /cova3d/, /cd/, /clooku/
!-----------------------------------------------------------------------
module visim_covariance_mod
  implicit none

  integer :: nst_max           ! max variogram structures
  integer :: nctx, ncty, nctz  ! covariance table dimensions
  integer :: maxctx_dim, maxcty_dim, maxctz_dim  ! max dims for bounds checking
  integer :: nlooku            ! lookup flag
  integer :: ncnode, nodmax    ! node search parameters
  integer :: nodmax_max        ! max dimension for nodmax
  integer :: isrot             ! rotation flag
  real :: cmax                 ! maximum covariance
  real :: cbb                  ! kriging variance parameter

  ! Variogram model parameters (allocated to nst_max)
  integer, allocatable :: nst(:)             ! number of structures (size 1)
  integer, allocatable :: it(:)              ! structure types
  real, allocatable :: c0(:)                 ! nugget (size 1)
  real, allocatable :: cc(:), aa(:)          ! contribution and range
  real, allocatable :: ang1(:), ang2(:), ang3(:)  ! angles
  real, allocatable :: anis1(:), anis2(:)    ! anisotropy ratios

  ! Rotation matrices (allocated to (nst_max+1) x 3 x 3)
  real*8, allocatable :: rotmat(:,:,:)

  ! Covariance lookup table (allocated to nctx x ncty x nctz)
  real, allocatable :: covtab(:,:,:)

  ! Volume covariance tables (double precision for accuracy)
  real*8, allocatable :: cv2v(:,:)           ! volume-to-volume (nvol x nvol)
  real*8, allocatable :: cd2v(:,:)           ! data-to-volume (nxyz x nvol)
  real*8, allocatable :: cd2d(:,:)           ! data-to-data (nxyz x nxyz)
  real, allocatable :: datacov(:,:)          ! data covariance (nvol x nvol)

  ! Node search arrays (allocated to nodmax)
  integer, allocatable :: icnode(:)          ! node flags
  integer, allocatable :: cnodeindex(:)      ! node indices
  real, allocatable :: cnodex(:), cnodey(:), cnodez(:)  ! node coordinates
  real, allocatable :: cnodev(:)             ! node values

  ! Covariance table indices (2-byte integers for memory efficiency)
  integer*2, allocatable :: ixnode(:), iynode(:), iznode(:)

contains

  subroutine allocate_covariance_arrays(maxnst, maxctx, maxcty, maxctz, &
                                         maxnod, maxvols, nxyz)
    integer, intent(in) :: maxnst, maxctx, maxcty, maxctz
    integer, intent(in) :: maxnod, maxvols, nxyz
    integer :: maxxyz, ierr

    nst_max = maxnst
    nctx = maxctx
    ncty = maxcty
    nctz = maxctz
    maxctx_dim = maxctx
    maxcty_dim = maxcty
    maxctz_dim = maxctz
    nodmax = maxnod
    nodmax_max = maxnod
    maxxyz = maxctx * maxcty * maxctz

    write(*,'(A,I0,A,I0,A,I0)') 'Allocating covariance arrays...'

    ! Variogram parameters
    allocate(nst(1), it(maxnst), stat=ierr)
    if (ierr /= 0) then
      write(*,*) 'ERROR: Failed to allocate nst/it arrays'
      stop 'ALLOCATION_FAILURE'
    end if

    allocate(c0(1), cc(maxnst), aa(maxnst), stat=ierr)
    if (ierr /= 0) then
      write(*,*) 'ERROR: Failed to allocate c0/cc/aa arrays'
      stop 'ALLOCATION_FAILURE'
    end if

    allocate(ang1(maxnst), ang2(maxnst), ang3(maxnst), stat=ierr)
    if (ierr /= 0) then
      write(*,*) 'ERROR: Failed to allocate angle arrays'
      stop 'ALLOCATION_FAILURE'
    end if

    allocate(anis1(maxnst), anis2(maxnst), stat=ierr)
    if (ierr /= 0) then
      write(*,*) 'ERROR: Failed to allocate anisotropy arrays'
      stop 'ALLOCATION_FAILURE'
    end if

    allocate(rotmat(maxnst+1, 3, 3), stat=ierr)
    if (ierr /= 0) then
      write(*,*) 'ERROR: Failed to allocate rotation matrices'
      stop 'ALLOCATION_FAILURE'
    end if

    ! Covariance lookup table
    allocate(covtab(maxctx, maxcty, maxctz), stat=ierr)
    if (ierr /= 0) then
      write(*,*) 'ERROR: Failed to allocate covtab array'
      write(*,*) '  Requested: ', maxctx, ' x ', maxcty, ' x ', maxctz
      write(*,*) '  Memory required: ~', maxxyz*4/1024/1024, ' MB'
      stop 'ALLOCATION_FAILURE'
    end if

    ! Volume covariance tables (LARGEST ARRAYS - can exceed 1 GB!)
    allocate(cv2v(maxvols, maxvols), stat=ierr)
    if (ierr /= 0) then
      write(*,*) 'ERROR: Failed to allocate cv2v array'
      write(*,*) '  Requested: ', maxvols, ' x ', maxvols
      write(*,*) '  Memory required: ~', maxvols*maxvols*8/1024/1024, ' MB'
      stop 'ALLOCATION_FAILURE'
    end if

    allocate(cd2v(nxyz, maxvols), stat=ierr)
    if (ierr /= 0) then
      write(*,*) 'ERROR: Failed to allocate cd2v array (CRITICAL - largest array!)'
      write(*,*) '  Requested: ', nxyz, ' x ', maxvols
      write(*,*) '  Memory required: ~', int8(nxyz)*int8(maxvols)*8/1024/1024, ' MB'
      write(*,*) 'SUGGESTION: Reduce grid size or number of volumes'
      write(*,*) '            or use read_covtable=1 to read from file'
      stop 'ALLOCATION_FAILURE'
    end if

    ! Data-to-data covariance table (NOTE: rarely used, commented out in most code)
    allocate(cd2d(nxyz, nxyz), stat=ierr)
    if (ierr /= 0) then
      write(*,*) 'ERROR: Failed to allocate cd2d array'
      write(*,*) '  Requested: ', nxyz, ' x ', nxyz
      write(*,*) '  Memory required: ~', int8(nxyz)*int8(nxyz)*8/1024/1024, ' MB'
      write(*,*) 'NOTE: This array is rarely used'
      stop 'ALLOCATION_FAILURE'
    end if

    allocate(datacov(maxvols, maxvols), stat=ierr)
    if (ierr /= 0) then
      write(*,*) 'ERROR: Failed to allocate datacov array'
      stop 'ALLOCATION_FAILURE'
    end if

    ! Node search arrays
    allocate(icnode(maxnod), cnodeindex(maxnod), stat=ierr)
    if (ierr /= 0) then
      write(*,*) 'ERROR: Failed to allocate node search arrays'
      stop 'ALLOCATION_FAILURE'
    end if

    allocate(cnodex(maxnod), cnodey(maxnod), cnodez(maxnod), cnodev(maxnod), stat=ierr)
    if (ierr /= 0) then
      write(*,*) 'ERROR: Failed to allocate node coordinate arrays'
      stop 'ALLOCATION_FAILURE'
    end if

    allocate(ixnode(maxxyz), iynode(maxxyz), iznode(maxxyz), stat=ierr)
    if (ierr /= 0) then
      write(*,*) 'ERROR: Failed to allocate covariance index arrays'
      stop 'ALLOCATION_FAILURE'
    end if

    write(*,'(A)') '  Covariance arrays allocated successfully'
    write(*,'(A,I0,A)') '  Total covariance memory: ~', &
      (maxxyz*4 + maxvols*maxvols*12 + int8(nxyz)*int8(maxvols)*8)/1024/1024, ' MB'

  end subroutine allocate_covariance_arrays

  subroutine deallocate_covariance_arrays()
    if (allocated(nst)) deallocate(nst, it)
    if (allocated(c0)) deallocate(c0, cc, aa)
    if (allocated(ang1)) deallocate(ang1, ang2, ang3, anis1, anis2)
    if (allocated(rotmat)) deallocate(rotmat)
    if (allocated(covtab)) deallocate(covtab)
    if (allocated(cv2v)) deallocate(cv2v)
    if (allocated(cd2v)) deallocate(cd2v)
    if (allocated(cd2d)) deallocate(cd2d)
    if (allocated(datacov)) deallocate(datacov)
    if (allocated(icnode)) deallocate(icnode, cnodeindex)
    if (allocated(cnodex)) deallocate(cnodex, cnodey, cnodez, cnodev)
    if (allocated(ixnode)) deallocate(ixnode, iynode, iznode)
  end subroutine deallocate_covariance_arrays

end module visim_covariance_mod

!-----------------------------------------------------------------------
! Module 6: visim_kriging_mod
! Purpose: Kriging system arrays (dynamically allocated)
! Replaces: /krigev/ (kriging arrays)
!-----------------------------------------------------------------------
module visim_kriging_mod
  implicit none

  integer :: maxkr1_max, maxkr2_max
  integer :: inovar            ! no variance flag
  real :: zmaxvar              ! maximum variance

  ! Kriging arrays (double precision for numerical stability)
  real*8, allocatable :: r(:), rr(:), s(:)   ! kriging vectors
  real*8, allocatable :: a(:)                 ! kriging matrix (maxkr1 x maxkr1)
  real, allocatable :: vra(:), vrea(:)       ! kriging values

contains

  subroutine allocate_kriging_arrays(maxnod, maxsam)
    integer, intent(in) :: maxnod, maxsam
    integer :: maxkr1, maxkr2, ierr

    maxkr1 = maxnod + maxsam + 1
    maxkr2 = maxkr1 * maxkr1
    maxkr1_max = maxkr1
    maxkr2_max = maxkr2

    write(*,'(A,I0,A,I0)') 'Allocating kriging arrays: system size = ', &
                           maxkr1, ' (matrix = ', maxkr2, ' elements)'

    allocate(r(maxkr1), rr(maxkr1), s(maxkr1), stat=ierr)
    if (ierr /= 0) then
      write(*,*) 'ERROR: Failed to allocate kriging vectors'
      stop 'ALLOCATION_FAILURE'
    end if

    allocate(a(maxkr2), stat=ierr)
    if (ierr /= 0) then
      write(*,*) 'ERROR: Failed to allocate kriging matrix'
      write(*,*) '  Requested: ', maxkr1, ' x ', maxkr1, ' = ', maxkr2
      write(*,*) '  Memory required: ~', maxkr2*8/1024/1024, ' MB'
      stop 'ALLOCATION_FAILURE'
    end if

    allocate(vra(maxkr1), vrea(maxkr1), stat=ierr)
    if (ierr /= 0) then
      write(*,*) 'ERROR: Failed to allocate vra/vrea arrays'
      stop 'ALLOCATION_FAILURE'
    end if

    write(*,'(A,I0,A)') '  Kriging arrays allocated successfully (', &
                        maxkr2*8/1024/1024, ' MB for matrix)'

  end subroutine allocate_kriging_arrays

  subroutine deallocate_kriging_arrays()
    if (allocated(r)) deallocate(r, rr, s)
    if (allocated(a)) deallocate(a)
    if (allocated(vra)) deallocate(vra, vrea)
  end subroutine deallocate_kriging_arrays

end module visim_kriging_mod

!-----------------------------------------------------------------------
! Module 7: visim_search_mod
! Purpose: Search parameters and super block structure
! Replaces: /search/ and super block arrays
!-----------------------------------------------------------------------
module visim_search_mod
  implicit none

  ! Search ellipsoid parameters
  real :: radius, radsqd       ! search radius and squared
  real :: sang1, sang2, sang3  ! search angles
  real :: sanis1, sanis2       ! search anisotropy

  ! Search constraints
  integer :: noct              ! octant search flag
  integer :: nclose            ! number of close data
  integer :: ndmin, ndmax      ! min/max data to use
  integer :: sstrat            ! search strategy
  integer :: mults, nmult      ! multiple grid search

  ! Super block search
  integer :: maxsbx, maxsby, maxsbz, maxsb
  integer :: maxsbx_dim, maxsby_dim, maxsbz_dim  ! Dimension parameters for super block (for bounds)
  integer :: nsbtosr                         ! number of super blocks to search
  integer, allocatable :: nisb(:)            ! nodes in super block
  integer*2, allocatable :: ixsbtosr(:)      ! super block X indices
  integer*2, allocatable :: iysbtosr(:)      ! super block Y indices
  integer*2, allocatable :: izsbtosr(:)      ! super block Z indices

contains

  subroutine allocate_search_arrays(nx_sb, ny_sb, nz_sb)
    integer, intent(in) :: nx_sb, ny_sb, nz_sb
    integer :: nsb, ierr

    maxsbx = nx_sb
    maxsby = ny_sb
    maxsbz = nz_sb
    maxsb = nx_sb * ny_sb * nz_sb
    nsb = maxsb
    ! Set dimension parameters for bounds checking
    maxsbx_dim = nx_sb
    maxsby_dim = ny_sb
    maxsbz_dim = nz_sb

    write(*,'(A,I0,A,I0,A,I0,A,I0)') 'Allocating search arrays: ', &
                                     nx_sb, ' x ', ny_sb, ' x ', nz_sb, ' = ', nsb

    allocate(nisb(nsb), stat=ierr)
    if (ierr /= 0) then
      write(*,*) 'ERROR: Failed to allocate nisb array'
      stop 'ALLOCATION_FAILURE'
    end if

    allocate(ixsbtosr(8*nsb), iysbtosr(8*nsb), izsbtosr(8*nsb), stat=ierr)
    if (ierr /= 0) then
      write(*,*) 'ERROR: Failed to allocate super block index arrays'
      stop 'ALLOCATION_FAILURE'
    end if

  end subroutine allocate_search_arrays

  subroutine deallocate_search_arrays()
    if (allocated(nisb)) deallocate(nisb)
    if (allocated(ixsbtosr)) deallocate(ixsbtosr, iysbtosr, izsbtosr)
  end subroutine deallocate_search_arrays

end module visim_search_mod

!-----------------------------------------------------------------------
! Module 8: visim_histogram_mod
! Purpose: Histogram reproduction (DSSIM), transformation, bootstrap
! Replaces: /hrdssim/, /transcon/ (array parts), /bt/ (array parts)
!-----------------------------------------------------------------------
module visim_histogram_mod
  implicit none

  ! DSSIM conditional lookup tables (allocated to maxmvlook x maxmvlook)
  real, allocatable :: condlookup_mean(:,:)
  real, allocatable :: condlookup_var(:,:)
  real, allocatable :: condlookup_cpdf(:,:,:)  ! size (maxmvlook, maxmvlook, maxquan)

  ! Quantile arrays (allocated to maxquan)
  real, allocatable :: x_quan(:)
  real, allocatable :: x_quan_center(:)

contains

  subroutine allocate_histogram_arrays(maxmvlook, maxquan)
    integer, intent(in) :: maxmvlook, maxquan
    integer :: ierr

    write(*,'(A,I0,A,I0)') 'Allocating histogram arrays: lookup = ', &
                           maxmvlook, ' x ', maxmvlook

    allocate(condlookup_mean(maxmvlook, maxmvlook), stat=ierr)
    if (ierr /= 0) then
      write(*,*) 'ERROR: Failed to allocate condlookup_mean array'
      stop 'ALLOCATION_FAILURE'
    end if

    allocate(condlookup_var(maxmvlook, maxmvlook), stat=ierr)
    if (ierr /= 0) then
      write(*,*) 'ERROR: Failed to allocate condlookup_var array'
      stop 'ALLOCATION_FAILURE'
    end if

    allocate(condlookup_cpdf(maxmvlook, maxmvlook, maxquan), stat=ierr)
    if (ierr /= 0) then
      write(*,*) 'ERROR: Failed to allocate condlookup_cpdf array'
      write(*,*) '  Requested: ', maxmvlook, ' x ', maxmvlook, ' x ', maxquan
      write(*,*) '  Memory required: ~', &
                 maxmvlook*maxmvlook*maxquan*4/1024/1024, ' MB'
      stop 'ALLOCATION_FAILURE'
    end if

    allocate(x_quan(maxquan), x_quan_center(maxquan), stat=ierr)
    if (ierr /= 0) then
      write(*,*) 'ERROR: Failed to allocate quantile arrays'
      stop 'ALLOCATION_FAILURE'
    end if

  end subroutine allocate_histogram_arrays

  subroutine deallocate_histogram_arrays()
    if (allocated(condlookup_mean)) deallocate(condlookup_mean)
    if (allocated(condlookup_var)) deallocate(condlookup_var)
    if (allocated(condlookup_cpdf)) deallocate(condlookup_cpdf)
    if (allocated(x_quan)) deallocate(x_quan, x_quan_center)
  end subroutine deallocate_histogram_arrays

end module visim_histogram_mod

!-----------------------------------------------------------------------
! Module 9: visim_random_mod
! Purpose: Random number generator state (ACORN)
! Replaces: /iaco/, /iaco2/
! Note: These arrays are fixed size (MAXOP1 = 13), not dynamically allocated
!-----------------------------------------------------------------------
module visim_random_mod
  implicit none

  integer, parameter :: MAXOP1 = 13

  ! Random seed
  integer :: idum

  ! ACORN RNG state (primary)
  integer :: ixv(MAXOP1), itr(MAXOP1)

  ! ACORN RNG state (secondary)
  integer :: ixv2(MAXOP1), itr2(MAXOP1)

end module visim_random_mod
