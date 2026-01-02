!%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
!                                                                      %
! Copyright (C) 1996, The Board of Trustees of the Leland Stanford    %
! Junior University.  All rights reserved.                            %
!                                                                      %
! Converted to Fortran 90 - 2026                                      %
!                                                                      %
!%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
!
! This file contains two subroutines for conditional tables (DSSIM):
!   - create_condtab: Builds lookup table for conditional probability
!   - drawfrom_condtab: Draws from the lookup table
!
! See Oz et al 2003 or Deutsch 2000 for details.
!-----------------------------------------------------------------------

subroutine create_condtab()
!-----------------------------------------------------------------------
!
!     Builds a lookup table for the local shape of the
!     conditional probability.
!     See Oz et. al 2003 or Deutsch 2000, for details.
!
!     INPUT VARIABLES:
!
!     OUTPUT VARIABLES:
!
!     condtab : conditional prob lookup table
!
!     ORIGINAL : Thomas Mejer Hansen                       DATE: August 2005
!
!-----------------------------------------------------------------------
  use visim_params_mod
  use visim_data_mod
  use visim_histogram_mod
  implicit none

  ! Local variables
  integer :: i, j, k, im, iv, i_monte
  real :: Gmean, gGvar
  real :: sum_sim, sum_sim2
  real :: mean_sim, var_sim
  real :: p, zt, ierr, simu
  real :: arr(20)
  real :: target(nbt)
  real :: target_nscore(nbt)
  real :: target_nscore_center(nbt)
  real :: target_p(nbt), temp(nbt)
  real :: target_weight(nbt)
  integer :: itarget_quan
  real :: ierror
  real :: q_norm, q_back(599)
  real :: x_cpdf(1500)
  real :: backtrans
  integer :: index_cdf
  character(len=80) :: tmpfl
  real :: te
  real*8 :: dummy1, dummy2, draw, draw_l, draw_h
  integer :: GmeanType, GvarType
  real :: backtr

  ! External GSLIB functions
  external :: nscore, gauinv, backtr

  GmeanType = 0
  GvarType = 0

  do i = 1, nbt
    target(i) = bootvar(i)
    ! NEXT LINE TO MAKE SURE ALL DATA HAVE WEIGHT 1
    target_weight(i) = 1.0
  end do

  ! Compute Normal Score of TARGET HISTOGRAM
  call nscore(nbt, target, zmin, zmax, 0, target_weight, temp, 1, &
              target_nscore, ierror, discrete)
  ! Centered normal scores
  call nscore(nbt, target, zmin, zmax, 0, target_weight, temp, 1, &
              target_nscore_center, ierror, 0)

  ! WRITING NSCORE TABLE TO FILE
  tmpfl = 'nscore' // '_' // outfl

  open(39, file=tmpfl, status='unknown')
  do i = 1, nbt
    write(39, *) target(i), target_nscore(i), target_nscore_center(i), &
                 target_weight(i), zmin, zmax
  end do
  close(39)

  ! Set up quantiles
  if (discrete == 1) then
    do i = 1, n_q
      x_quan(i) = (i) * (1.0 / n_q)
    end do
  else
    do i = 1, n_q
      x_quan(i) = (i - 1) * (1.0 / (n_q - 1))
    end do
  end if

  do i = 1, n_q
    x_quan_center(i) = (i - 1) * (1.0 / n_q) + (1.0 / n_q) / 2.0
  end do

  if (idbg > 0) then
    write(*, *) ' Nscore MEAN range=', min_Gmean, max_Gmean, n_Gmean
    write(*, *) ' Nscore VAR range = ', min_Gvar, max_Gvar, n_Gvar
    write(*, *) ' Number of quantiles = ', n_q
    write(*, *) ' Number of samples drawn in nscore space= ', n_monte
    write(*, *) 'Calc CondPDF Lookup n_Gmean,n_Gvar=', n_Gmean, n_Gvar
  end if

  do im = 1, n_Gmean
    Gmean = min_Gmean + (im - 1) * (max_Gmean - min_Gmean) / (n_Gmean - 1)

    if (idbg >= 2) then
      write(*, *) 'precalc lookup im,n_Gmean=', im, n_Gmean, Gmean
    end if

    do iv = 1, n_Gvar
      gGvar = min_Gvar + (iv - 1) * (max_Gvar - min_Gvar) / (n_Gvar - 1)

      if (iv == 1) gGvar = min_Gvar

      ! BACK TRANSFORM QUANTILES
      dummy1 = 0.0
      dummy2 = 0.0
      do i = 1, n_q
        call gauinv(dble(x_quan_center(i)), zt, ierr)
        q_norm = zt * sqrt(gGvar) + Gmean

        x_cpdf(i) = backtr(q_norm, nbt, target, target_nscore_center, &
                           zmin, zmax, ltail, ltpar, utail, utpar, discrete)

        dummy1 = dummy1 + x_cpdf(i)
        dummy2 = dummy2 + x_cpdf(i) * x_cpdf(i)
      end do

      dummy1 = dummy1 / n_q
      dummy2 = dummy2 / n_q
      dummy2 = dummy2 - dummy1 * dummy1

      mean_sim = dummy1
      var_sim = dummy2

      if (var_sim < 0.0) var_sim = 0.0

      condlookup_mean(im, iv) = mean_sim
      condlookup_var(im, iv) = var_sim
      do i = 1, n_q
        condlookup_cpdf(im, iv, i) = x_cpdf(i)
      end do

      if (idbg > 2) then
        write(*, *) 'gm,gv,mean_sim,mean_var', Gmean, gGvar, mean_sim, var_sim
      end if
    end do
  end do

  ! Write lookup tables to disk
  if (idbg > 0) then
    tmpfl = 'cond_imean' // '_' // outfl
    open(29, file=tmpfl, status='unknown')
    tmpfl = 'cond_mean' // '_' // outfl
    open(30, file=tmpfl, status='unknown')
    tmpfl = 'cond_var' // '_' // outfl
    open(31, file=tmpfl, status='unknown')
    tmpfl = 'cond_cpdf' // '_' // outfl
    open(32, file=tmpfl, status='unknown')

    do im = 1, n_Gmean
      do iv = 1, n_Gvar
        write(29, *) im
        write(30, *) condlookup_mean(im, iv)
        write(31, *) condlookup_var(im, iv)
        if (idbg > 0) then
          do i = 1, n_q
            write(32, *) condlookup_cpdf(im, iv, i)
          end do
        end if
      end do
    end do
    close(29)
    close(30)
    close(31)
    close(32)
  end if

  return

end subroutine create_condtab


real function drawfrom_condtab(cmean, cvar, p)
!-----------------------------------------------------------------------
!
!     Draw from a lookup table for the local shape of the
!     conditional probability.
!     See Oz et. al 2003 or Deutsch 2000, for details.
!
!     INPUT VARIABLES:
!
!     cmean, cvar : conditional mean and variance
!     p           : random probability value
!
!     OUTPUT VARIABLES:
!
!     drawfrom_condtab : drawn value
!
!     ORIGINAL : Thomas Mejer Hansen                       DATE: August 2005
!
!-----------------------------------------------------------------------
  use visim_params_mod
  use visim_histogram_mod
  implicit none

  ! Arguments
  real, intent(in) :: cmean, cvar, p

  ! Local variables
  integer :: im, iv, iq, ie, is_local, xid
  real :: cmean_arr(500), i_arr(500)
  real :: i_mean(500), mean(500)
  real :: dist
  real :: mindist
  integer :: im_sel, iv_sel
  real :: m_sel, v_sel
  integer :: index_cdf
  real :: Kmean, Kstd, Fmean, Fstd, draw
  real :: dm, dv
  real :: h, draw_a, draw_b
  real*8 :: draw_l, draw_h
  integer :: i
  integer :: doOzCorr
  real :: cvar_local

  cvar_local = cvar * cvar

  ! Normalize mean using the max-min values on the normal score transformation
  dm = zmax - zmin

  ! Normalize variance using the global variance
  dv = gvar

  ! Find the conditional distribution in normal score space
  ! that matches the conditional mean and variance in original space
  mindist = 1.0e+9
  do im = 1, n_Gmean
    do iv = 1, n_Gvar
      ! OZ STYLE
      dist = ((condlookup_mean(im, iv) - cmean) / dm)**2 + &
             abs(condlookup_var(im, iv) - cvar_local) / sqrt(dv)

      if (dist < mindist) then
        mindist = dist
        im_sel = im
        iv_sel = iv
      end if
    end do
  end do

  m_sel = condlookup_mean(im_sel, iv_sel)
  v_sel = condlookup_var(im_sel, iv_sel)

  if (idbg > 2) then
    write(*, *) '-- looking up in condtab'
    write(*, *) 'cmean,cvar=', cmean, ' ', cvar_local
    write(*, *) 'm_sel=', m_sel, im_sel
    write(*, *) 'v_sel=', v_sel, iv_sel
  end if

  ! Locate quantile
  index_cdf = 1
  do i = 1, n_q
    if (x_quan(i) > p) then
      index_cdf = i
      exit
    end if
  end do

  if (p > x_quan(n_q)) then
    index_cdf = n_q
  end if

  if (discrete == 1) then
    ! FIND ARRAY
    draw = condlookup_cpdf(im_sel, iv_sel, index_cdf)
  else
    ! ASSUME CONTINUOUS TARGET HISTOGRAM
    ! Interpolate
    draw_h = condlookup_cpdf(im_sel, iv_sel, index_cdf)
    draw_l = condlookup_cpdf(im_sel, iv_sel, index_cdf - 1)

    h = x_quan(index_cdf) - x_quan(index_cdf - 1)
    draw_a = draw_h * (x_quan(index_cdf) - p) / h
    draw_b = draw_l * (p - x_quan(index_cdf - 1)) / h

    draw = draw_a + draw_b

    ! Handle tails
    if (p < x_quan(1)) then
      draw = condlookup_cpdf(im_sel, iv_sel, 1)
    end if
    if (p > x_quan(n_q)) then
      draw = condlookup_cpdf(im_sel, iv_sel, n_q)
    end if
  end if

  drawfrom_condtab = draw

  ! CORRECTION ACCORDING TO Oz et al, 2003
  doOzCorr = 0
  if (doOzCorr == 1) then
    Fmean = condlookup_mean(im_sel, iv_sel)
    Fstd = sqrt(condlookup_var(im_sel, iv_sel))

    Kmean = cmean
    Kstd = sqrt(cvar_local)

    if (Fstd < 0.00001) then
      write(*, *) 'draw=', drawfrom_condtab, Fmean, Fstd, Kmean, Kstd
    end if

    drawfrom_condtab = (draw - Fmean) * (Kstd / Fstd) + Kmean

    if (Fstd < 0.00001) then
      write(*, *) 'draw=', drawfrom_condtab, Fmean, Fstd, Kmean, Kstd
      stop
    end if
  end if

  return

end function drawfrom_condtab
