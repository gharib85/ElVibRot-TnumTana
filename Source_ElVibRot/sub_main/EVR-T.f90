!===========================================================================
!===========================================================================
!This file is part of ElVibRot.
!
!    ElVibRot is free software: you can redistribute it and/or modify
!    it under the terms of the GNU Lesser General Public License as published by
!    the Free Software Foundation, either version 3 of the License, or
!    (at your option) any later version.
!
!    ElVibRot is distributed in the hope that it will be useful,
!    but WITHOUT ANY WARRANTY; without even the implied warranty of
!    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
!    GNU Lesser General Public License for more details.
!
!    You should have received a copy of the GNU Lesser General Public License
!    along with ElVibRot.  If not, see <http://www.gnu.org/licenses/>.
!
!    Copyright 2015  David Lauvergnat
!      with contributions of Mamadou Ndong, Josep Maria Luis
!
!    ElVibRot includes:
!        - Tnum-Tana under the GNU LGPL3 license
!        - Somme subroutines of John Burkardt under GNU LGPL license
!             http://people.sc.fsu.edu/~jburkardt/
!        - Somme subroutines of SHTOOLS written by Mark A. Wieczorek under BSD license
!             http://shtools.ipgp.fr
!===========================================================================
!%LATEX-USER-DOC-Driver
!
!\begin{itemize}
!  \item
!    Time independent calculations: energy levels, spectrum with intensities...
!  \item
!    Time dependent calculations (wavepacket propagations):
!    propagations with time dependent field, relaxation, optimal control ...
!\end{itemize}
!
!The main originality concerns the use of numerical kinetic energy operator (Tnum),
! which enables a large flexibility in the choice of the curvilinear coordinates.
!
!\section(Input file)
!
!The input file has four mains sections:
!\begin{itemize}
!  \item
!   SYSTEM and CONSTANTS, which define general parameters for parallelization, printing levels, energy unit, physical constants...
!  \item
!   COORDINATES, which defines the curvilinear coordinates, the coordinates transformations and some aspects of the physical models (constraints....). This section is part of Tnum.
!  \item
!   OPERATORS and BASIS SETS, which define parameters of scalar operators (potential, dipole moments...) and the active and inactive basis set (contracted).
!  \item
!   ANALYSIS, which defines parameters for time dependent (including optimal control) or independent calculations, intensities.
!\end{itemize}
!%END-LATEX-USER-DOC-Driver
!===========================================================================
    PROGRAM ElVibRot
      USE mod_system
!$    USE omp_lib, only : omp_get_max_threads
      USE mod_nDGridFit
      USE mod_MPI
      IMPLICIT NONE

      logical  :: intensity_only,analysis_only,Popenmp,Popenmpi
      integer  :: PMatOp_omp,POpPsi_omp,PBasisTOGrid_omp,PGrid_omp,optimization
      integer  :: maxth,PMatOp_maxth,POpPsi_maxth,PBasisTOGrid_maxth,PGrid_maxth
      integer  :: PSG4_omp,PSG4_maxth
      integer (kind=ILkind)  :: max_mem
      integer  :: printlevel,err
      logical  :: test,EVR,cart,nDfit,nDGrid,mem_debug
      logical  :: GridTOBasis_test,OpPsi_test,main_test
      character (len=Name_longlen) :: EneFormat
      character (len=Name_longlen) :: RMatFormat
      character (len=Name_longlen) :: CMatFormat
      character (len=Line_len)     :: base_FileName = ''
      
      ! parameters for system setup
      ! make sure to be prepared in file      
      namelist /system/ max_mem,mem_debug,test,printlevel,              &

                          Popenmp,Popenmpi,                             &
                          PSG4_omp,PSG4_maxth,                          &
                          PMatOp_omp,PMatOp_maxth,                      &
                          POpPsi_omp,POpPsi_maxth,                      &
                          PBasisTOGrid_omp,PBasisTOGrid_maxth,          &
                          PGrid_omp,PGrid_maxth,                        &

                          RMatFormat,CMatFormat,EneFormat,              &

                          intensity_only,analysis_only,EVR,cart,        &
                          GridTOBasis_test,OpPsi_test,                  &
                          optimization,nDfit,nDGrid,                    &
                          main_test,                                    &

                          EVRT_path,File_path,base_FileName

        !> initialize MPI
        !> id=0 to be the master
        !---------------------------------------------------------------------------------
#if(run_MPI)
        CALL MPI_initialization()
        Popenmpi           = .TRUE.  !< True to run MPI, set here or in namelist system
        Popenmp            = .FALSE.  !< True to run openMP
#else 
        MPI_id=0
        Popenmpi           = .FALSE.  !< True to run MPI, set here or in namelist system
        ! set openMP accodring to make file
#if(run_openMP)
        Popenmp            = .True.   !< True to run openMP
#else
        Popenmp            = .FALSE. 
#endif
#endif
 
        intensity_only     = .FALSE.
        analysis_only      = .FALSE.
        test               = .FALSE.
        cart               = .FALSE.
        GridTOBasis_test   = .FALSE.
        OpPsi_test         = .FALSE.   !< True for test of action
        EVR                = .FALSE.   ! ElVibRot (default)
        nDfit              = .FALSE.
        nDGrid             = .FALSE.
        main_test          = .FALSE.
        optimization       = 0

        maxth              = 1
        !$ maxth           = omp_get_max_threads()
        
        PMatOp_omp         = 0
        PMatOp_maxth       = maxth
        POpPsi_omp         = 0
        POpPsi_maxth       = maxth
        PBasisTOGrid_omp   = 0
        PBasisTOGrid_maxth = maxth
        PGrid_omp          = 1
        PGrid_maxth        = maxth

        PSG4_omp           = 1
        PSG4_maxth         = maxth

        max_mem          = 4000000000_ILkind/Rkind ! 4GO
        mem_debug        = .FALSE.
        printlevel       = -1

        EneFormat        = "f18.10"
        RMatFormat       = "f18.10"
        CMatFormat       = "f15.7"

        IF(MPI_id==0) THEN 
          ! version and copyright statement
          CALL versionEVRT(.TRUE.)
          write(out_unitp,*)
#if(run_MPI)
          CALL time_perso('MPI start, initial time')
          write(out_unitp,*) ' Initiaize MPI with ', MPI_np, 'cores.'
          write(out_unitp,*)
          write(*,*) 'Integer type of default Fortran Compiler:',sizeof(integer_MPI),  &
                                                        ', MPI: ',MPI_INTEGER_KIND
          write(out_unitp,*) 'NOTE: MPI version halfway. If get memory error, check if &
                                    the variables are just allocated on master process.'
#endif
        ENDIF


        !> read from parameter file created by shell script
        in_unitp=10
        open(in_unitp,file='namelist',STATUS='OLD',IOSTAT=err)
        IF(err/=0) THEN
          write(*,*) 'namelist file does not exist or error, reading namelist from shell'
          in_unitp=INPUT_UNIT
        ENDIF
        read(in_unitp,system,IOSTAT=err)
             
        IF (err < 0) THEN
          write(out_unitp,*) ' ERROR in ElVibRot (main program)'
          write(out_unitp,*) ' End-of-file or End-of-record'
          write(out_unitp,*) ' The namelist "system" is probably absent'
          write(out_unitp,*) ' check your data!'
          write(out_unitp,*) ' ERROR in ElVibRot (main program)'
          STOP
        ELSE IF (err > 0) THEN
          write(out_unitp,*) ' ERROR in ElVibRot (main program)'
          write(out_unitp,*) ' Some parameter name of the namelist "system" are probaly wrong'
          write(out_unitp,*) ' check your data!'
          write(out_unitp,system)
          write(out_unitp,*) ' ERROR in ElVibRot (main program)'
          STOP
        END IF

        IF (base_FileName /= "" .AND. File_path /= "") THEN
          write(out_unitp,*) ' ERROR in ElVibRot (main program)'
          write(out_unitp,*) ' base_FileName and File_path are both set!!'
          write(out_unitp,*) ' You MUST define only File_path.'
          write(out_unitp,*) ' check your data!'
          write(out_unitp,system)
          write(out_unitp,*) ' ERROR in ElVibRot (main program)'
          STOP
        ELSE IF (base_FileName /= "") THEN
          File_path = base_FileName
        END IF

        para_mem%mem_debug = mem_debug

        EVR = .NOT. (analysis_only .OR. GridTOBasis_test .OR.            &
                     OpPsi_test .OR. cart .OR. main_test .OR. nDfit .OR. &
                     nDGrid .OR. optimization /= 0 .OR. analysis_only)

        IF (printlevel > 1) write(out_unitp,system)

        para_EVRT_calc%optimization     = optimization
        para_EVRT_calc%EVR              = EVR
        para_EVRT_calc%analysis_only    = analysis_only
        para_EVRT_calc%intensity_only   = intensity_only
        para_EVRT_calc%cart             = cart
        para_EVRT_calc%GridTOBasis_test = GridTOBasis_test
        para_EVRT_calc%OpPsi_test       = OpPsi_test

        para_EVRT_calc%nDfit            = nDfit
        para_EVRT_calc%nDGrid           = nDGrid
        para_EVRT_calc%main_test        = main_test

        print_level = printlevel ! print_level is in mod_system.mod

        EneIO_format  = EneFormat
        RMatIO_format = RMatFormat
        CMatIO_format = "'('," // trim(adjustl(CMatFormat)) //      &
                    ",' +i'," // trim(adjustl(CMatFormat)) // ",')'"


        openmp              = Popenmp ! openmp is in mod_system.mod
        openmpi             = Popenmpi
        
        IF (.NOT. openmp) THEN
           MatOp_omp          = 0
           OpPsi_omp          = 0
           BasisTOGrid_omp    = 0
           Grid_omp           = 0
           SG4_omp            = 0

           MatOp_maxth        = 1
           OpPsi_maxth        = 1
           BasisTOGrid_maxth  = 1
           Grid_maxth         = 1
           SG4_maxth          = 1
        ELSE
           MatOp_omp          = PMatOp_omp
           OpPsi_omp          = POpPsi_omp
           BasisTOGrid_omp    = PBasisTOGrid_omp
           Grid_omp           = PGrid_omp
           SG4_omp            = PSG4_omp

           IF (MatOp_omp > 0) THEN
             MatOp_maxth        = min(PMatOp_maxth,maxth)
           ELSE
             MatOp_maxth        = 1
           END IF

           IF (OpPsi_omp > 0) THEN
             OpPsi_maxth        = min(POpPsi_maxth,maxth)
           ELSE
             OpPsi_maxth        = 1
           END IF

           IF (BasisTOGrid_omp > 0) THEN
             BasisTOGrid_maxth  = min(PBasisTOGrid_maxth,maxth)
           ELSE
             BasisTOGrid_maxth  = 1
           END IF

           IF (Grid_omp > 0) THEN
             Grid_maxth         = min(PGrid_maxth,maxth)
           ELSE
             Grid_maxth         = 1
           END IF

           IF (SG4_omp > 0) THEN
             SG4_maxth         = PSG4_maxth
           ELSE
             SG4_maxth         = 1
           END IF

        END IF

        IF(MPI_id==0 .AND. .NOT. openmpi) THEN
          write(out_unitp,*) '========================================='
          write(out_unitp,*) 'OpenMP parameters:'
          write(out_unitp,*) 'Max number of threads:           ',maxth
          write(out_unitp,*) 'MatOp_omp,      MatOp_maxth      ',MatOp_omp,MatOp_maxth
          write(out_unitp,*) 'OpPsi_omp,      OpPsi_maxth      ',OpPsi_omp,OpPsi_maxth
          write(out_unitp,*) 'BasisTOGrid_omp,BasisTOGrid_maxth',BasisTOGrid_omp,BasisTOGrid_maxth
          write(out_unitp,*) 'Grid_omp,       Grid_maxth       ',Grid_omp,Grid_maxth
          write(out_unitp,*) 'SG4_omp,        SG4_maxth        ',SG4_omp,SG4_maxth
          write(out_unitp,*) '========================================='
          
          write(out_unitp,*) '========================================='
          write(out_unitp,*) 'File_path: ',trim(adjustl(File_path))
          write(out_unitp,*) '========================================='
        ENDIF ! for MPI_id=0
        
        para_mem%max_mem    = max_mem/Rkind
        IF(MPI_id==0) THEN
          write(out_unitp,*) '========================================='
          write(out_unitp,*) '========================================='
        ENDIF ! for MPI_id=0

        IF (para_EVRT_calc%optimization /= 0) THEN
          IF(MPI_id==0) write(out_unitp,*) ' Optimization calculation'
          IF(MPI_id==0) write(out_unitp,*) '========================================='
          CALL sub_Optimization_OF_VibParam(max_mem)

        ELSE IF (para_EVRT_calc%nDfit .OR. para_EVRT_calc%nDGrid) THEN
          IF(MPI_id==0) write(out_unitp,*) ' nDfit or nDGrid calculation'
          IF(MPI_id==0) write(out_unitp,*) '========================================='
          CALL sub_nDGrid_nDfit()

        ELSE IF (para_EVRT_calc%EVR) THEN
          IF(MPI_id==0) write(out_unitp,*) ' ElVibRot calculation'
          IF(MPI_id==0) write(out_unitp,*) '========================================='
          CALL vib(max_mem,test,intensity_only)

        ELSE IF (para_EVRT_calc%cart) THEN
          IF(MPI_id==0) write(out_unitp,*) ' cart calculation'
          IF(MPI_id==0) write(out_unitp,*) '========================================='
          CALL sub_cart(max_mem)

        ELSE IF (para_EVRT_calc%GridTOBasis_test) THEN
          IF(MPI_id==0) write(out_unitp,*) ' sub_GridTOBasis calculation'
          IF(MPI_id==0) write(out_unitp,*) '========================================='
          CALL sub_GridTOBasis_test(max_mem)

        ELSE IF (para_EVRT_calc%OpPsi_test) THEN
          IF(MPI_id==0) write(out_unitp,*) ' OpPsi calculation'
          IF(MPI_id==0) write(out_unitp,*) '========================================='
          CALL Sub_OpPsi_test(max_mem)

        ELSE IF (para_EVRT_calc%analysis_only) THEN
          IF(MPI_id==0) write(out_unitp,*) ' WP analysis calculation'
          IF(MPI_id==0) write(out_unitp,*) '========================================='
          CALL sub_analysis_only(max_mem)

        ELSE IF (para_EVRT_calc%main_test) THEN
          IF(MPI_id==0) write(out_unitp,*) ' Smolyat test calculation'
          IF(MPI_id==0) write(out_unitp,*) '========================================='
          CALL sub_main_Smolyak_test()

        ELSE
          IF(MPI_id==0) write(out_unitp,*) ' ElVibRot calculation (default)'
          IF(MPI_id==0) write(out_unitp,*) '========================================='
          CALL vib(max_mem,test,intensity_only)
        END IF

        IF(MPI_id==0) THEN
          write(out_unitp,*) '========================================='
          write(out_unitp,*) '========================================='
        ENDIF ! for MPI_id=0

#if(run_MPI)
        IF(MPI_id==0) THEN
          write(*,*) 'time check for action: ',                                        &
                    real(time_MPI_action,Rkind)/real(time_rate,Rkind),' from ',MPI_id
          write(*,*) 'time MPI comm check: ',                                          &
                    real(time_comm,Rkind)/real(time_rate,Rkind),' from ', MPI_id
        ENDIF
        !> end MPI
        CALL time_perso('MPI closed, final time')
        CALL MPI_Finalize(MPI_err);
        close(in_unitp)
#endif        
      END PROGRAM ElVibRot

