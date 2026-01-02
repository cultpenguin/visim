!%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
!                                                                      %
! Copyright (C) 1996, The Board of Trustees of the Leland Stanford    %
! Junior University.  All rights reserved.                            %
!                                                                      %
! Converted to Fortran 90 - 2026                                      %
!                                                                      %
!%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
!
! This file contains two subroutines for data transformation:
!   - pre_trans: Read in and prepare the target histogram
!   - trans: Transform simulated values to match reference distribution
!
!-----------------------------------------------------------------------

subroutine pre_trans
!-----------------------------------------------------------------------
!
! The subroutine is called to read in the target histogram from another
! file. It is only called once when doing multiple realizations
!
! INPUT/OUTPUT Parameters
!
!  distin      file with target histogram
!  ivrr,iwtr   columns for variable and weight(0=none)
!  tmin,tmax   trimming limits
!
!-----------------------------------------------------------------------
  use visim_params_mod
  use visim_data_mod
  use visim_histogram_mod
  implicit none

  ! Local variables
  real :: var(50)
  logical :: testfl
  character(len=512) :: str
  integer :: i, j, nvari
  real :: vrt_local, wtt_local
  real :: tcdf, oldcp, cp
  real :: gmedian
  integer :: c, d, e, f, g, h
  real :: powint

  ! External GSLIB functions
  external :: sortem, locate, powint

  ! Check if reference distribution file exists
  inquire(file=distin, exist=testfl)
  if (.not. testfl) then
    write(*, *) 'ERROR: No reference distribution file'
    stop
  end if

  open(lin, file=distin, status='UNKNOWN')

  ! Read the file header
  read(lin, '(a)', err=198) str
  read(lin, *, err=198) nvari
  do i = 1, nvari
    read(lin, '()', err=198)
  end do

  ! Read as much data for target histogram as possible
  ncut = 0
  tcdf = 0.0

  do while (.true.)
    read(lin, *, end=3, err=198) (var(j), j=1, nvari)

    if (var(ivrr) < tmin .or. var(ivrr) >= tmax) cycle

    vrt_local = var(ivrr)
    wtt_local = 1.0
    if (iwtr >= 1) wtt_local = var(iwtr)

    ncut = ncut + 1
    if (ncut > nref_max) then
      write(*, *) 'ERROR: exceeded available storage for'
      write(*, *) '       reference, available: ', nref_max
      stop
    end if

    rvr(ncut) = vrt_local
    rcdf(ncut) = wtt_local
    tcdf = tcdf + wtt_local
  end do

3 close(lin)

  ! Sort the Reference Distribution and Check for error situation
  call sortem(1, ncut, rvr, 1, rcdf, c, d, e, f, g, h)

  if (ncut <= 1 .or. tcdf <= EPSLON) then
    write(*, *) 'ERROR: too few data or too low weight'
    stop
  end if

  if (utail == 4 .and. rvr(ncut) <= 0.0) then
    write(*, *) 'ERROR can not use hyperbolic tail with '
    write(*, *) '      negative values! - see manual '
    stop
  end if

  ! Turn the (possibly weighted) distribution into a cdf that is useful
  tcdf = 1.0 / tcdf
  oldcp = 0.0
  cp = 0.0
  do i = 1, ncut
    cp = cp + rcdf(i) * tcdf
    rcdf(i) = (cp + oldcp) * 0.5
    oldcp = cp
  end do

  if (idbg >= 3) then
    write(ldbg, *) 'after sortem and calc the correct rcdf rvr='
    write(ldbg, *) (rvr(i), i=1, ncut)
    write(ldbg, *) 'after sortem and calc the correct rcdf rcdf='
    write(ldbg, *) (rcdf(i), i=1, ncut)
  end if

  ! Write Some of the Statistics to the screen
  call locate(rcdf, ncut, 1, ncut, 0.5, j)
  gmedian = powint(rcdf(j), rcdf(j+1), rvr(j), rvr(j+1), 0.5, 1.0)
  write(*, 900) ncut, gmedian
900 format(/' There are ', i8, ' data in reference dist,', /, &
           '   median value        = ', f12.5)

  if (idbg >= 3) then
    write(ldbg, *) 'ncut=', ncut
    write(ldbg, *) 'in pre_trans rvr='
    write(ldbg, *) (rvr(i), i=1, ncut)
    write(ldbg, *) 'in pre_trans rcdf='
    write(ldbg, *) (rcdf(i), i=1, ncut)
  end if

  return

198 stop 'ERROR in global data file!'

end subroutine pre_trans


subroutine trans
!-----------------------------------------------------------------------
!
!                      Univariate Transformation
!                      *************************
!
! Transforms the values in each of the sequential simulation
! such that their histograms match that of the reference distribution.
!
! INPUT/OUTPUT Parameters:
!
!   sim         dataset with uncorrected distributions
!   tmin,tmax   trimming limits
!   outfl       file for output distributions
!   nsim        size to transform, number of realizations
!   nx, ny, nz  size of categorical variable realizations to transform
!   nxyz        size of continuous variable data set to transform
!   zmin,zmax   minimum and maximum data values
!   ltail,ltpar lower tail: option, parameter
!   utail,utpar upper tail: option, parameter
!   icond       honor local data (1=yes, 0=no)
!   localfl     file with estimation variance
!   ikv         column number
!   wtfac       control parameter
!
!-----------------------------------------------------------------------
  use visim_params_mod
  use visim_data_mod
  use visim_grid_mod
  use visim_histogram_mod
  implicit none

  ! Local variables
  character(len=40) :: str
  real :: var(20)
  logical :: testfl
  integer :: ivrd_local, iwtd_local
  real :: tcdf, oldcp, cp
  integer :: num, i, j
  real :: wtd_local
  integer :: d, e, f, g, h
  real :: evmax, zval, wtw
  integer :: ne, nvarik
  real :: av, ss
  real :: getz

  ! External GSLIB functions
  external :: sortem, getz, numtext

  print *, 'Transforming data '

  if (idbg >= 3) then
    write(*, *) 'The simulation results from visim is shown below'
    write(ldbg, *) (sim(i), i=1, nxyz)
  end if

  if (idbg >= 3) then
    write(ldbg, *) 'isim=', isim, 'nsim=', nsim
  end if

  ivrd_local = 1
  iwtd_local = 0

  ! Transfer the data values from visim simulation sim() to dvr()
  tcdf = 0.0
  num = 0
  do i = 1, nxyz
    num = num + 1
    dvr(num) = sim(i)
    indx(num) = real(num)
    wtd_local = 1.0
    dcdf(num) = wtd_local
    tcdf = tcdf + wtd_local
  end do

  if (tcdf <= EPSLON) then
    write(*, *) 'ERROR: no data'
    stop
  end if

  ! Turn the (possibly weighted) data distribution into a useful cdf
  call sortem(1, num, dvr, 2, dcdf, indx, d, e, f, g, h)

  oldcp = 0.0
  cp = 0.0
  tcdf = 1.0 / tcdf

  do i = 1, num
    cp = cp + dcdf(i) * tcdf
    dcdf(i) = (cp + oldcp) / 2.0
    if (dcdf(i) >= 1.0) dcdf(i) = 0.99
    oldcp = cp
  end do

  ! Now, get the right order back
  call sortem(1, num, indx, 2, dcdf, dvr, d, e, f, g, h)

  ! Get the kriging variance to array "indx" if we have to honor local data
  if (icond == 1) then
    if (ivar == 1) then
      open(lkv, file=localfl, err=195, status='OLD')
      read(lkv, '()', err=195)
      read(lkv, *, err=195) nvarik
      do i = 1, nvarik
        read(lkv, '()', err=195)
      end do
      evmax = -1.0e21
      do i = 1, num
        read(lkv, *, err=195) (var(j), j=1, nvarik)
        indx(i) = var(icoll)
        indx(i) = sqrt(max(indx(i), 0.0))
        if (indx(i) > evmax) evmax = indx(i)
      end do
      close(lkv)
    else
      evmax = -1.0e21
      do i = 1, num
        indx(i) = krgvar(i)
        indx(i) = sqrt(max(indx(i), 0.0))
        if (indx(i) > evmax) evmax = indx(i)
      end do
    end if
  end if

  ! Go through all the data back transforming them to the reference CDF
  ne = 0
  av = 0.0
  ss = 0.0

  do i = 1, num
    zval = getz(dcdf(i), ncut, rvr, rcdf, zmin, &
                zmax, ltail, ltpar, utail, utpar)

    ! Now, do we have to honor local data?
    if (icond == 1) then
      if (indx(i) == 0.0) then
        wtw = 0.0
      else
        wtw = (indx(i) / evmax)**wtfac
      end if
      zval = dvr(i) + wtw * (zval - dvr(i))
    end if

    ne = ne + 1
    av = av + zval
    ss = ss + zval * zval
    if (idbg >= 3) then
      write(ldbg, *) 'The transformed value is :'
      write(ldbg, *) zval
    end if
    call numtext(zval, str(1:12))
    write(lout, '(a12)') str(1:12)
  end do

  ! Calculate some statistics
  av = av / max(real(ne), 1.0)
  ss = (ss / max(real(ne), 1.0)) - av * av
  if (idbg > -2) then
    print *, 'Finished trans'
    write(ldbg, 112) isim, ne, av, ss
    write(*, 112) isim, ne, av, ss
112 format(/, ' Realization ', i3, ': number   = ', i8, /, &
           '                  mean     = ', f12.4, &
           ' (close to target mean)', /, &
           '                  variance = ', f12.4, &
           ' (close to target variance)', /)
  end if

  return

195 stop 'ERROR in kriging variance file!'

end subroutine trans
