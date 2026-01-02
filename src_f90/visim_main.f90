!%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
!                                                                      %
! Copyright (C) 1996, The Board of Trustees of the Leland Stanford    %
! Junior University.  All rights reserved.                            %
!                                                                      %
! VISIM - Volume Integration SIMulation                               %
! Modernized to Fortran 90 - 2026                                     %
!                                                                      %
!%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
!-----------------------------------------------------------------------
!
!                Volume Integration SIMulation
!                ******************************
!
! The program is executed by specifying the parameter file as a
! command-line argument:
!   visim_f90 visim.par
!
! Or with no command-line arguments, in which case the user will be
! prompted for the parameter file name.
!
! The output file will be a GEOEAS file containing the simulated values.
! The file is ordered by x, y, z, and then simulation (i.e., x cycles
! fastest, then y, then z, then simulation number).
!
!-----------------------------------------------------------------------

program visim_main
  use visim_params_mod
  use visim_data_mod
  use visim_grid_mod
  use visim_volume_mod
  use visim_covariance_mod
  use visim_kriging_mod
  use visim_search_mod
  use visim_histogram_mod
  use visim_random_mod
  use visim_allocate
  use visim_readpar_v2
  implicit none

  ! Local variables for dimension requirements (temporary holders)
  integer :: maxdat, maxvols, maxdinvol
  integer :: maxnod, maxsam, maxnst
  integer :: maxctx, maxcty, maxctz
  integer :: maxsbx_local, maxsby_local, maxsbz_local
  integer :: maxquan, maxmvlook, maxref, maxcat
  integer :: ierr

  write(*,*)
  write(*,*) '************************************************************'
  write(*,*) '*                                                          *'
  write(*,*) '*              VISIM - Fortran 90 Version                  *'
  write(*,*) '*      Volume Integration SIMulation with Dynamic          *'
  write(*,*) '*              Memory Allocation                           *'
  write(*,*) '*                                                          *'
  write(*,'(A,F5.2,A)') ' *              Version ', VERSION, '                                 *'
  write(*,*) '*                                                          *'
  write(*,*) '************************************************************'
  write(*,*)

  !=====================================================================
  ! PHASE 1: Read parameter file to determine dimension requirements
  !=====================================================================

  write(*,*) '======================================================='
  write(*,*) 'PHASE 1: Determining dimension requirements'
  write(*,*) '======================================================='
  write(*,*)

  call readparm_get_dimensions(maxdat, maxvols, maxdinvol, &
                                maxnod, maxsam, maxnst, &
                                maxctx, maxcty, maxctz, &
                                maxsbx_local, maxsby_local, maxsbz_local, &
                                maxquan, maxmvlook, maxref, maxcat)

  !=====================================================================
  ! PHASE 2: Allocate all arrays based on dimension requirements
  !=====================================================================

  write(*,*)
  write(*,*) '======================================================='
  write(*,*) 'PHASE 2: Allocating dynamic arrays'
  write(*,*) '======================================================='

  call allocate_all_arrays(maxdat, maxvols, maxdinvol, &
                            maxnod, maxsam, maxnst, &
                            maxctx, maxcty, maxctz, &
                            maxsbx_local, maxsby_local, maxsbz_local, &
                            maxquan, maxmvlook, maxref, maxcat, &
                            nx, ny, nz, ierr)

  if (ierr /= 0) then
    write(*,*) 'FATAL ERROR: Memory allocation failed with code ', ierr
    write(*,*) 'Terminating program.'
    stop 1
  end if

  !=====================================================================
  ! PHASE 3: Read parameter file again and populate arrays
  !=====================================================================

  write(*,*)
  write(*,*) '======================================================='
  write(*,*) 'PHASE 3: Reading parameters and data'
  write(*,*) '======================================================='
  write(*,*)

  call readparm_populate()

  !=====================================================================
  ! PHASE 4: Main simulation loop
  !=====================================================================

  write(*,*)
  write(*,*) '======================================================='
  write(*,*) 'PHASE 4: Running simulation'
  write(*,*) '======================================================='
  write(*,*)

  ! Create conditional probability lookup table (if DSSIM mode)
  if (idrawopt == 1) then
    write(*,*) 'Creating conditional probability lookup table (DSSIM)...'
    call create_condtab()
  end if

  ! Open output file
  open(lout, file=outfl, status='UNKNOWN')
  write(lout,'(A)') 'VISIM F90 Simulation Output'
  write(lout,'(A,I0)') 'Number of realizations: ', nsim
  write(lout,'(A,I0,A,I0,A,I0)') 'Grid: ', nx, ' x ', ny, ' x ', nz

  ! Main simulation loop
  write(*,*)
  write(*,'(A,I0,A)') 'Simulating ', nsim, ' realization(s)...'
  write(*,*)

  do isim = 1, nsim
    if (nsim > 1) then
      write(*,'(A,I0,A,I0)') 'Realization ', isim, ' of ', nsim
    end if

    ! Call main simulation subroutine
    call visim

    ! Write results (handled in visim or trans subroutine)

  end do

  close(lout)

  write(*,*)
  write(*,*) 'Simulation complete!'
  write(*,'(A,A)') '  Output written to: ', trim(outfl)
  write(*,*)

  !=====================================================================
  ! PHASE 5: Cleanup and exit
  !=====================================================================

  write(*,*)
  write(*,*) '======================================================='
  write(*,*) 'PHASE 5: Cleanup'
  write(*,*) '======================================================='
  write(*,*)

  call deallocate_all_arrays()

  write(*,*)
  write(*,*) '************************************************************'
  write(*,*) '*                                                          *'
  write(*,*) '*           VISIM F90 completed successfully!              *'
  write(*,*) '*                                                          *'
  write(*,*) '************************************************************'
  write(*,*)

  stop 0

end program visim_main
