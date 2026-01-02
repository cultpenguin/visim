!-----------------------------------------------------------------------
! Extended parameter population routines
! This is a separate module to keep readpar_v2 manageable
!-----------------------------------------------------------------------

module visim_readpar_populate
  use visim_params_mod
  use visim_data_mod
  use visim_grid_mod
  use visim_volume_mod
  use visim_covariance_mod
  use visim_kriging_mod
  use visim_search_mod
  use visim_histogram_mod
  use visim_random_mod
  implicit none

  ! Module variable to store parameter filename
  character(len=512), save :: current_parfile = 'visim.par'

  ! External GSLIB functions
  external :: chknam
  real*8, external :: acorni

contains

!-----------------------------------------------------------------------
! populate_all_parameters - Complete parameter reading implementation
!-----------------------------------------------------------------------
subroutine populate_all_parameters()
  character(len=512) :: datafl, volgeomfl, volsumfl, dbgfl, tmpfl
  integer :: ixl, iyl, izl, ivrl, iwt, isecvr
  integer :: i, test, argc
  real :: radius1, radius2, aa1, aa2, sill
  real :: av, ss
  real*8 :: p, acorni
  integer :: idum
  logical :: testfl

  ! Initialize file units
  lin = 1
  lout = 2
  ldbg = 3
  llvm = 4
  lkv = 5
  lout_mean = 26

  ! Initialize debug level (will be overridden by parameter file)
  idbg = 0

  write(*,*) 'Reading parameters from file...'

  ! Open parameter file
  open(lin, file=trim(get_parfile_name()), status='OLD')

  ! Find START marker (legacy format) - skip for keyword format
  call find_start_marker()

  ! Read main parameters
  read(lin, *, err=98) icond
  if (idbg > 0) write(*,*) 'Conditional simulation flag:', icond

  read(lin, '(a)', err=98) datafl
  call chknam(datafl, 40)
  if (idbg > 0) write(*,*) 'Data file:', trim(datafl)

  read(lin, *, err=98) ixl, iyl, izl, ivrl
  iwt = 0
  isecvr = 0

  read(lin, '(a)', err=98) volgeomfl
  call chknam(volgeomfl, 40)

  read(lin, '(a)', err=98) volsumfl
  call chknam(volsumfl, 40)

  read(lin, *, err=98) tmin, tmax
  if (idbg > 0) write(*,*) 'Trimming limits:', tmin, tmax

  read(lin, *, err=98) idbg, read_covtable, read_lambda, read_volnh, read_randpath, do_cholesky, do_error_sim
  if (idbg > -2) write(*,*) 'VISIM', VERSION, trim(get_parfile_name())

  read(lin, '(a)', err=98) outfl
  call chknam(outfl, 40)
  if (idbg > 0) write(*,*) 'Output file:', trim(outfl)

  tmpfl = 'debug_' // trim(outfl)
  open(ldbg, file=tmpfl, status='UNKNOWN')

  read(lin, *, err=98) nsim
  if (nsim == 0) then
    nsim = 1
    doestimation = 1
    if (idbg > 0) write(*,*) 'Doing ESTIMATION rather than SIMULATION'
  else
    doestimation = 0
    if (idbg > 0) write(*,*) 'Number of realizations:', nsim
  end if

  read(lin, *, err=98) idrawopt
  if (idbg > 0) write(*,*) 'Distribution type:', idrawopt

  ! Read DSSIM parameters (always present in file, even if not used)
  read(lin, '(a)', err=98) tmpfl  ! btfl - target histogram file
  read(lin, *, err=98) ibt, ibtw
  read(lin, *, err=98) min_Gmean, max_Gmean, n_Gmean
  read(lin, *, err=98) min_Gvar, max_Gvar, n_Gvar
  read(lin, *, err=98) n_q, discrete
  n_monte = 1000
  if (idrawopt /= 1) then
    if (idbg > 0) write(*,*) 'Using Gaussian (idrawopt=0), DSSIM params skipped'
  end if

  ! Grid dimensions (already read in get_dimensions, but validate)
  read(lin, *, err=98) nx, xmn, xsiz
  read(lin, *, err=98) ny, ymn, ysiz
  read(lin, *, err=98) nz, zmn, zsiz
  nxy = nx * ny
  nxyz = nx * ny * nz

  if (idbg > 0) then
    write(*,*) 'Grid: ', nx, 'x', ny, 'x', nz
  end if

  ! Random seed
  read(lin, *, err=98) ixv(1)
  ixv2(1) = ixv(1)
  if (idbg > 0) write(*,*) 'Random seed:', ixv(1)

  ! Initialize random number generator
  p = acorni(idum)
  do i = 1, 1000
    p = acorni(idum)
  end do

  ! Search parameters
  read(lin, *, err=98) ndmin, ndmax
  read(lin, *, err=98) nodmax

  read(lin, *, err=98) musevols, nusevols, accept_fract
  if (doestimation == 1) then
    ! musevols = 0
  end if

  read(lin, *, err=98) densitypr
  if (doestimation == 1 .and. densitypr /= 0) then
    densitypr = 0
    if (idbg >= -1) write(*,*) 'Forcing random path for estimation'
  end if
  ! For unconditional simulation, force independent random path
  if (icond == 0 .and. densitypr /= 0) then
    densitypr = 0
    if (idbg >= -1) write(*,*) 'Forcing independent path for unconditional simulation'
  end if

  read(lin, *, err=98) sstrat
  mults = 0
  nmult = 1

  read(lin, *, err=98) noct

  read(lin, *, err=98) radius, radius1, radius2
  if (radius < EPSLON) stop 'Radius must be greater than zero'
  radsqd = radius * radius
  sanis1 = radius1 / radius
  sanis2 = radius2 / radius

  read(lin, *, err=98) sang1, sang2, sang3

  ! Kriging type (forced to SK for now)
  ktype = 0
  colocorr = 1.0
  varred = 1.0

  read(lin, *, err=98) skgmean, gvar

  ! Secondary data disabled
  icollvm = 0

  ! Variogram
  read(lin, *, err=98) nst(1), c0(1)
  sill = c0(1)
  if (idbg > 0) write(*,*) 'NST, C0:', nst(1), c0(1)

  if (nst(1) <= 0) then
    write(*,*) 'ERROR: nst must be at least 1'
    stop
  end if

  do i = 1, nst(1)
    read(lin, *, err=98) it(i), cc(i), ang1(i), ang2(i), ang3(i)
    read(lin, *, err=98) aa(i), aa1, aa2
    anis1(i) = aa1 / max(aa(i), EPSLON)
    anis2(i) = aa2 / max(aa(i), EPSLON)
    sill = sill + cc(i)

    if (it(i) == 4) then
      write(*,*) 'ERROR: Power model not allowed'
      stop
    end if

    if (idbg > 0) then
      write(*,*) 'Structure', i, ':', it(i), cc(i)
      write(*,*) '  Ranges:', aa(i), aa1, aa2
    end if
  end do

  ! Transformation parameters
  itrans = 0
  if (idrawopt == 1) then
    read(lin, *, err=98) zmin, zmax
    read(lin, *, err=98) ltail, ltpar
    read(lin, *, err=98) utail, utpar
  end if

  close(lin)

  ! Validate grid dimensions
  if (nx * ny * nz > mxyz_max) then
    write(*,*) 'ERROR: Grid exceeds allocated memory'
    write(*,*) '  Requested:', nx, 'x', ny, 'x', nz, '=', nx*ny*nz
    write(*,*) '  Allocated:', mxyz_max
    stop
  end if

  ! Handle conditional vs unconditional simulation
  nd = 0
  av = 0.0
  ss = 0.0

  if (icond >= 1) then
    inquire(file=datafl, exist=testfl)
    if (.not. testfl) then
      write(*,*) 'WARNING: Data file not found:', trim(datafl)
      write(*,*) 'For unconditional simulation, set icond=0'
    else
      ! Read conditioning data
      call read_data_file(datafl, ixl, iyl, izl, ivrl)
    end if
  else
    ! Unconditional simulation
    ndmin = 0
    ndmax = 0
    sstrat = 1
  end if

  if (icond == 2) then
    ! Condition to volume data only
    ndmin = 0
    ndmax = 0
    sstrat = 1
  end if

  write(*,*) 'Parameters read successfully'
  write(*,*) '  Grid:', nx, 'x', ny, 'x', nz
  write(*,*) '  Realizations:', nsim
  write(*,*) '  Conditioning data:', nd, 'points'

  return

98 write(*,*) 'ERROR: Problem reading parameter file'
   stop

end subroutine populate_all_parameters

!-----------------------------------------------------------------------
! Helper routines
!-----------------------------------------------------------------------

function get_parfile_name() result(filename)
  character(len=512) :: filename
  filename = current_parfile
end function

subroutine set_parfile_name(filename)
  character(len=*), intent(in) :: filename
  current_parfile = filename
end subroutine

subroutine find_start_marker()
  character(len=4) :: str
  do
    read(lin, '(a4)', end=10) str
    if (str == 'STAR') exit
  end do
  return
10 rewind(lin)
end subroutine

subroutine read_data_file(datafl, ixl, iyl, izl, ivrl)
  character(len=*), intent(in) :: datafl
  integer, intent(in) :: ixl, iyl, izl, ivrl
  integer :: lin_data, ierr, i, test
  character(len=512) :: str
  real :: vrr

  write(*,*) 'Reading conditioning data from:', trim(datafl)

  lin_data = 10
  open(lin_data, file=datafl, status='OLD', err=99)

  ! Read header
  read(lin_data, '(a)', err=99) str
  read(lin_data, *, err=99) test

  ! Count data points
  nd = 0
  do
    read(lin_data, *, end=20, err=20) vrr
    nd = nd + 1
  end do

20 rewind(lin_data)

  ! Skip header again
  read(lin_data, '(a)') str
  read(lin_data, *) test

  ! Read data
  do i = 1, nd
    if (i > nd_max) then
      write(*,*) 'ERROR: Too many data points'
      write(*,*) '  Found:', nd
      write(*,*) '  Allocated:', nd_max
      stop
    end if

    read(lin_data, *, err=99) x(i), y(i), z(i), vr(i)
    wt(i) = 1.0  ! Equal weights
  end do

  close(lin_data)
  write(*,*) 'Read', nd, 'data points'
  return

99 write(*,*) 'ERROR: Problem reading data file:', trim(datafl)
   close(lin_data)
   stop

end subroutine read_data_file

end module visim_readpar_populate
